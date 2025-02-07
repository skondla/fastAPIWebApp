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

def db_attach(db_url: str, instance_class: str):
    instance_name = db_url.split('.')[0]
    cluster_name = instance_name
    today = datetime.datetime.now().strftime("%m%d-%H%M")
    instance_name = f"{instance_name}-{today}"

    get_db_info = RDSDescribe().dbInstanceInfo(db_url)
    db_security_group, db_subnet, engine, database, engine_version = map(str, get_db_info[:5])

    print(f"instanceName: {instance_name}")
    print(f"engine: {engine}")
    print(f"engineVersion: {engine_version}")
    print(f"instanceClass: {instance_class}")
    print(f"clusterName: {cluster_name}")

    return RDSCreate().create_db_cluster_instance(
        instance_name, cluster_name, engine, engine_version, instance_class
    )

@auth_router.post("/attachdb")
async def attach_db(db_url: str, instance_class: str):
    response = db_attach(db_url, instance_class)
    return {"message": "Database instance is being attached", "response": response}

def slackPost(*args):
    today = datetime.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    webhook_url = 'https://hooks.slack.com/services/XXXX/XXXX/xyyyybbbbssssrm01' 
    slack_data = {"channel": "@skondla", "username": args[4], 'text': today + ": " + args[3] + " Database: " + \
            args[0] + " is " + args[2] + \
            " for dB Endpoint: "  + args[1], "icon_emoji": ":man-biking:"}
    region = 'us-east-1'
  
    response = requests.post(
    webhook_url, data=json.dumps(slack_data),
    headers={'Content-Type': 'application/json'}
    )
    if response.status_code != 200:
       raise ValueError(
        'Request to slack returned an error %s, the response is:\n%s'
        % (response.status_code, response.text)
       )    

def sendEmail(*args):
        with open('/app/email_distro', 'r') as f:
	        email_distro = f.read()
        os.system("echo dB: " + args[0] + " is " + args[2] + \
                 " for dB: "  + args[1] + "|mailx -s 'dB Restore'" + email_distro)
        
##

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

def get_ip(request: Request) -> str:
    """Extracts the client IP address from request headers."""
    if forwarded_for := request.headers.get("X-Forwarded-For"):
        return forwarded_for.split(",")[0]  # Get the first IP in the list
    return request.client.host if request.client else "Unknown"

def log_user_info(email: str, request_type: str, endpoint: str, comments: str, request: Request, db: Session):
    """Logs user activity into the database."""
    today = datetime.datetime.now().strftime("%Y%m%d%H%M")
    user_ip = get_ip(request)

    logged_user = Userinfo(
        email=email,
        ip=user_ip,
        time=today,
        requesttype=request_type,
        endpoint=endpoint,
        comments=comments,
    )

    db.add(logged_user)
    db.commit()
    db.refresh(logged_user)
    return logged_user

@auth_router.post("/log-user-info/")
async def log_user_info_api(
    email: str, 
    request_type: str, 
    endpoint: str, 
    comments: str, 
    request: Request, 
    db: Session = Depends(get_db)
):
    """API endpoint to log user activity."""
    log_entry = log_user_info(email, request_type, endpoint, comments, request, db)
    return {"message": "User info logged successfully", "log": log_entry}