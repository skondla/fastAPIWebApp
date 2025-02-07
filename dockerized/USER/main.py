#!/usr/bin/env python3
#Author: skondla@me.com
#purpose: Build a simple python WebApp & REST API to call database service requests
# -*- coding: utf-8 -*-
# main.py

from fastapi import FastAPI, Depends, Request
from fastapi.templating import Jinja2Templates
from starlette.responses import HTMLResponse

app = FastAPI()

# Setup Jinja2 template rendering
templates = Jinja2Templates(directory="templates")

# Dependency to get the current user (Mock for now)
def get_current_user():
    return {"name": "Test User"}  # Replace with actual authentication logic

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/restore", response_class=HTMLResponse)
async def restore(request: Request, user: dict = Depends(get_current_user)):
    return templates.TemplateResponse("restore.html", {"request": request, "name": user["name"]})

@app.get("/status", response_class=HTMLResponse)
async def status(request: Request, user: dict = Depends(get_current_user)):
    return templates.TemplateResponse("status.html", {"request": request, "name": user["name"]})

@app.get("/attachdb", response_class=HTMLResponse)
async def attachdb(request: Request, user: dict = Depends(get_current_user)):
    return templates.TemplateResponse("attachdb.html", {"request": request, "name": user["name"]})
