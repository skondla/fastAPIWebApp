#!/usr/bin/env python3
#Author: skondla@me.com
#purpose: Build a simple python WebApp & REST API to call database service requests
# -*- coding: utf-8 -*-
# init.py

import os
from fastapi import FastAPI, Depends
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
from .database import Base, get_db
from .models import User, Userinfo
from .auth import router as auth_router
from .main import router as main_router

# Load environment variables from .env file
load_dotenv()

# Database Configuration
DATABASE_URL = f"postgresql://{os.getenv('suser')}:{os.getenv('spassword')}@" \
               f"{os.getenv('shost')}:{os.getenv('sport')}/{os.getenv('sdatabase')}"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create the FastAPI App
app = FastAPI(title="FastAPI App", version="1.0")

# Dependency for database sessions
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Database Initialization
Base.metadata.create_all(bind=engine)

# Register Routers
app.include_router(auth_router, prefix="/auth")
app.include_router(main_router, prefix="/main")

# Root Endpoint
@app.get("/")
def read_root():
    return {"message": "Welcome to the FastAPI Application"}

