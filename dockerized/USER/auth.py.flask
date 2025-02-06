#!/usr/bin/env python3
#Author: skondla@me.com
#purpose: Build a simple python WebApp & REST API to call database service requests
# -*- coding: utf-8 -*-
# auth.py

from flask import Blueprint, render_template, redirect, url_for, request, flash, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from flask_login import login_user, logout_user, login_required
from .models import User, Userinfo
from . import db
from rdsAdmin import RDSDescribe, RDSCreate, RDSDelete, RDSRestore
import json
import requests
import simplejson
import datetime
#import functools
from flask import session
import boto3
from botocore.exceptions import ClientError
import os


auth = Blueprint('auth', __name__)

@auth.route('/login')
def login():
    return render_template('login.html')

@auth.route('/login', methods=['POST'])
def login_post():
    email = request.form.get('email')
    password = request.form.get('password')
    remember = True if request.form.get('remember') else False
    ip = getIP()
    print('Client IP Address: ' + str(ip))

    user = User.query.filter_by(email=email).first()

    # check if user actually exists
    # take the user supplied password, hash it, and compare it to the hashed password in database
    if not user or not check_password_hash(user.password, password): 
        flash('Please check your login details and try again.')
        return redirect(url_for('auth.login')) # if user doesn't exist or password is wrong, reload the page

    # if the above check passes, then we know the user has the right credentials
    login_user(user, remember=remember)
    #userInfo(email,ip)
    requesttype=""
    endpoint=""
    comments=""
    session["email"] = email
    session["password"] = password
    print('EMAIL: ' + session["email"]) 
    userInfo("Initial Login",endpoint,comments)
   
    return redirect(url_for('main.restore'))

@auth.route('/signup')
def signup():
    return render_template('signup.html')

@auth.route('/signup', methods=['POST'])
def signup_post():

    email = request.form.get('email')
    name = request.form.get('name')
    password = request.form.get('password')
    user = User.query.filter_by(email=email).first() # if this returns a user, then the email already exists in database
    if user: # if a user is found, we want to redirect back to signup page so user can try again  
        flash('Email address already exists')
        return redirect(url_for('auth.signup'))
    # create new user with the form data. Hash the password so plaintext version isn't saved.
    #new_user = User(email=email, name=name, password=generate_password_hash(password, method='scrypt'))
    new_user = User(email=email, name=name, password=generate_password_hash(password, method='sha256'))
    # add the new user to the database
    db.session.add(new_user)
    db.session.commit()
    return redirect(url_for('auth.login'))

@auth.route('/logout')
@login_required
def logout():
    logout_user()
    session.clear()
    return redirect(url_for('main.index'))

@auth.route('/restore')
@login_required
def restore():
    return render_template('restore.html')

@auth.route('/restore', methods=['GET','POST'])
def restore_post():
    snapshotName = request.form['snapshotname']
    snapshotName = snapshotName.strip()
    endPoint = request.form['endpoint']
    endPoint = endPoint.strip()
    newEndpont = snapshotName + '.' + endPoint.split('.',1)[1]	
    try:
        restoreStatus = dbRestore(snapshotName,endPoint)
    except ClientError as e:
        return ("Unexpected error restoreStatus: %s" % e)    
    
    try:
        dbState = dbStatus(endPoint,snapshotName)
    except ClientError as e:
        return ("Unexpected error dbStatus: %s" % e)    

    userInfo('DB Restore',newEndpont,snapshotName)
    slackPost(snapshotName,newEndpont,dbState, "Restoring","dbRestore")
    sendEmail(snapshotName,endPoint,dbState)
    return "Database: " + str(snapshotName) + " is being restored from " + str(snapshotName) + \
        "New Endpoint: ^^ " + newEndpont + "^^ DB Restore status: " + str(dbState), 202

def dbStatus(endPoint,newEndPoint):
    #newEndPoint = newEndPoint.split('.')[0]
    if 'cluster' in endPoint:
        return RDSDescribe().getDBClusterStatus(newEndPoint)
    else:
        return RDSDescribe().getDBInstanceStatus(newEndPoint)
        
def dbRestore(snapshotName,dBURL):
    if 'cluster' in dBURL:
        getDBInfo = list()
        getDBInfo = RDSDescribe().dbInstanceInfo(dBURL)
        dbSecurityGroup = str(getDBInfo[0])
        dbSubNet = str(getDBInfo[1])
        engine = str(getDBInfo[2])
        database = str(getDBInfo[3])
        engineVersion = str(getDBInfo[4])
        endpoint = dBURL.split('.')[0]
        print (dBURL + ' is a cluster')
        print ('snapshotName: ' + snapshotName)
        print ('getDBInfo: ' + str(getDBInfo))
        #return RDSDescribe().dbInstanceInfo(dBURL)
        return RDSRestore().restore_db_cluster_from_snapshot(
            snapshotName,snapshotName,dbSubNet,dbSecurityGroup,engine,engineVersion)
    else:
        getDBInfo = list()
        getDBInfo = RDSDescribe().dbInstanceInfo(dBURL)
        dbSecurityGroup = str(getDBInfo[0])
        dbSubNet = str(getDBInfo[1])
        engine = str(getDBInfo[2])
        database = str(getDBInfo[3])
        engineVersion = str(getDBInfo[4])
        instanceClass = str(getDBInfo[5])
        print (dBURL + ' is NOT a cluster')
        print ('snapshotName: ' + snapshotName)
        print ('getDBInfo: ' + str(getDBInfo))
        #return RDSDescribe().dbInstanceInfo(dBURL)
        return RDSRestore().restore_db_instance_from_db_snapshot(
            snapshotName,snapshotName,dbSubNet,dbSecurityGroup,engine,instanceClass)

def dbAttach(dBURL,instanceClass):
        instanceName = dBURL.split('.')[0]
        clusterName = instanceName
        #today = datetime.datetime.now().strftime("%Y%m%d-%H%M")
        today = datetime.datetime.now().strftime("%m%d-%H%M")
        instanceName = str(instanceName) + "-" + str(today)
        getDBInfo = list()
        getDBInfo = RDSDescribe().dbInstanceInfo(dBURL)
        dbSecurityGroup = str(getDBInfo[0])
        dbSubNet = str(getDBInfo[1])
        engine = str(getDBInfo[2])
        database = str(getDBInfo[3])
        engineVersion = str(getDBInfo[4])
        endpoint = dBURL.split('.')[0]
        print('instanceName: ' + instanceName)
        print('engine: ' + engine)
        print('engineVersion: ' + engineVersion)
        #print('dbSubNet: ' + dbSubNet)
        #print('dbSecurityGroup: ' + dbSecurityGroup)
        print('instanceClass: ' + instanceClass)
        print('clusterName: ' + clusterName)
        return RDSCreate().create_db_cluster_instance(
            instanceName,clusterName,engine,engineVersion,instanceClass)
        
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

@auth.route('/status')
@login_required
#@auth.login_required
def status():
    #logout_user()
    #session.clear()
    return render_template('status.html')
    #return render_template('main.index')

@auth.route('/status', methods=['GET','POST'])
#@login_required
def status_post():
   #if not session["email"] and not session["password"]:
    #    return "Email and/or Password is not valid"
    snapshotName = request.form['snapshotname']
    snapshotName = snapshotName.strip()
    endPoint = request.form['endpoint']
    endPoint = endPoint.strip()
    #newEndpont = snapshotName + '.' + endPoint.split('.',1)[1]
    try:
        dbState = dbStatus(endPoint,snapshotName)
    except ClientError as e:
        return ("Unexpected error: %s" % e)    
    #dbState = dbStatus(endPoint,snapshotName)
    userInfo('DB Status',endPoint,snapshotName)
    slackPost(snapshotName,endPoint,dbState, "Status of","dbStatus")
    sendEmail(snapshotName,endPoint,dbState)
    return "Database: " + str(snapshotName) + " status: " + str(dbState), 202

@auth.route('/attachdb')
@login_required
def attachdb():
    return render_template('attachdb.html')

@auth.route('/attachdb', methods=['GET','POST'])
def attachdb_post():
    endPoint = request.form['endpoint']
    endPoint = endPoint.strip()
    instanceClass = request.form['instanceclass']
    instanceClass = instanceClass.strip()
    if not 'cluster' in endPoint:
        return endPoint + " is not a cluster and cannot attach to a cluster", 202	
    try:
        attachStatus = dbAttach(endPoint,instanceClass)
    except ClientError as e:
        return ("Unexpected error: %s" % e)

    
    clusterName = endPoint.split('.')[0]
    #today = datetime.datetime.now().strftime("%Y%m%d-%H%M")
    today = datetime.datetime.now().strftime("%m%d-%H%M")
    instanceName = str(clusterName) + "-" + str(today)
    newEndpont = instanceName + '.' + endPoint.split('.',1)[1]
    slackPost(instanceName,newEndpont, "being attached","Attaching","dbAttach")
    userInfo('DB Attach',endPoint,instanceName)
    sendEmail(instanceName,endPoint,str(attachStatus))
    return "Database Instance: " + str(instanceName) + " is being attached to cluster New Endpoint: " + str(newEndpont), 202

def userInfo(*kwargs):
    today = str(datetime.datetime.now().strftime("%Y%m%d%H%M"))
    #requesttype=""
    #endpoint=""
    #comments=""
    logged_user = Userinfo(email=session["email"], ip=getIP(), time=today,requesttype=kwargs[0],endpoint=kwargs[1],comments=kwargs[2])
    # add the new user to the database
    db.session.add(logged_user)
    db.session.commit()
    #checkEMail = session["email"]
    
def getIP():
    if request.headers.getlist("X-Forwarded-For"):
       ip = request.headers.getlist("X-Forwarded-For")[0]
    else:
       ip = request.remote_addr
    return str(ip)
