#!/usr/bin/env python3
#Author: skondla@me.com
#purpose: Build a simple python WebApp & REST API to call database service requests
# -*- coding: utf-8 -*-
# main.py

from flask import Blueprint, render_template
from flask_login import login_required, current_user

main = Blueprint('main', __name__)

@main.route('/')
def index():
    return render_template('index.html')

#@main.route('/restoreDB')
#@login_required
#def restore():
#    return render_template('restoreDB.html', name=current_user.name)

@main.route('/restore')
@login_required
def restore():
    return render_template('restore.html', name=current_user.name)
    #return render_template('restore.html', name=current_user.name,ip=request.remote_addr)

@main.route('/status')
@login_required
def status():
    return render_template('status.html', name=current_user.name)

@main.route('/attachdb')
@login_required
def attachdb():
    return render_template('attachdb.html', name=current_user.name)

#@main.route('/profile')
#@login_required
#def profile():
#    return render_template('profile.html', name=current_user.name)
