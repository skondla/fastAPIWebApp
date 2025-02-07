#!/usr/bin/env python3
#Author: skondla@me.com
#purpose: Build a simple python WebApp & REST API to call database service requests
# -*- coding: utf-8 -*-
# models.py


from . import db
from sqlalchemy import Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(100), unique=True, nullable=False)
    password = Column(String(1000), nullable=False)
    name = Column(String(1000), nullable=False)

class Userinfo(Base):
    __tablename__ = "user_info"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(100), unique=True, nullable=False)
    ip = Column(String(50), nullable=False)
    time = Column(String(60), nullable=False)
    requesttype = Column(String(30))
    endpoint = Column(String(100))
    comments = Column(String(200))
