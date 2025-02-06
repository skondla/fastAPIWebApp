#!/usr/bin/env python3
#Author: skondla@me.com
#purpose: Build a simple python WebApp & REST API to call database service requests
# -*- coding: utf-8 -*-
# auth.py

from fastapi import APIRouter, Depends, HTTPException, Request, Form, status
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from fastapi_login import LoginManager
from .models import User, Userinfo, get_db
from .rdsAdmin import RDSDescribe, RDSCreate, RDSDelete, RDSRestore
import json
import requests
import datetime
import os
import boto3
from botocore.exceptions import ClientError

# Initialize router
auth_router = APIRouter()

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Authentication Manager
SECRET = "your-secret-key"
manager = LoginManager(SECRET, token_url="/auth/token")

@manager.user_loader
def get_user(email: str, db: Session = Depends(get_db)):
    return db.query(User).filter(User.email == email).first()

@auth_router.get("/login", response_class=HTMLResponse)
def login_page():
    return "Render login.html"

@auth_router.post("/login")
def login_post(email: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    user = get_user(email, db)
    if not user or not pwd_context.verify(password, user.password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    access_token = manager.create_access_token(data={"sub": email})
    return JSONResponse(content={"access_token": access_token})

@auth_router.get("/signup", response_class=HTMLResponse)
def signup_page():
    return "Render signup.html"

@auth_router.post("/signup")
def signup_post(email: str = Form(...), name: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    user = get_user(email, db)
    if user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already exists")
    hashed_password = pwd_context.hash(password)
    new_user = User(email=email, name=name, password=hashed_password)
    db.add(new_user)
    db.commit()
    return RedirectResponse(url="/login", status_code=status.HTTP_302_FOUND)

@auth_router.get("/logout")
def logout():
    response = RedirectResponse(url="/")
    response.delete_cookie("Authorization")
    return response

@auth_router.get("/restore", response_class=HTMLResponse)
def restore_page():
    return "Render restore.html"

@auth_router.post("/restore")
def restore_post(snapshot_name: str = Form(...), endpoint: str = Form(...)):
    snapshot_name = snapshot_name.strip()
    endpoint = endpoint.strip()
    new_endpoint = f"{snapshot_name}.{endpoint.split('.',1)[1]}"
    try:
        restore_status = db_restore(snapshot_name, endpoint)
    except ClientError as e:
        raise HTTPException(status_code=500, detail=f"Restore Error: {str(e)}")
    
    db_state = db_status(endpoint, snapshot_name)
    return JSONResponse(content={"snapshot_name": snapshot_name, "status": db_state, "new_endpoint": new_endpoint})

def db_status(endpoint, new_endpoint):
    if 'cluster' in endpoint:
        return RDSDescribe().getDBClusterStatus(new_endpoint)
    else:
        return RDSDescribe().getDBInstanceStatus(new_endpoint)

def db_restore(snapshot_name, db_url):
    if 'cluster' in db_url:
        db_info = RDSDescribe().dbInstanceInfo(db_url)
        return RDSRestore().restore_db_cluster_from_snapshot(snapshot_name, snapshot_name, *db_info[:5])
    else:
        db_info = RDSDescribe().dbInstanceInfo(db_url)
        return RDSRestore().restore_db_instance_from_db_snapshot(snapshot_name, snapshot_name, *db_info[:6])

@auth_router.get("/status", response_class=HTMLResponse)
def status_page():
    return "Render status.html"

@auth_router.post("/status")
def status_post(snapshot_name: str = Form(...), endpoint: str = Form(...)):
    snapshot_name = snapshot_name.strip()
    endpoint = endpoint.strip()
    try:
        db_state = db_status(endpoint, snapshot_name)
    except ClientError as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")
    return JSONResponse(content={"snapshot_name": snapshot_name, "status": db_state})
