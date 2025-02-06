#!/usr/bin/env python3
#Author: skondla@me.com
#purpose: Build a simple python WebApp & REST API to call database service requests
# -*- coding: utf-8 -*-
# init.py

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager 
#import utils, os
import os

# init SQLAlchemy so we can use it later in our models
db = SQLAlchemy()

def create_app():
    app = Flask(__name__)

    app.config['SECRET_KEY'] = 's3dgMHEPR47DlmXNmb9hvHfj99U53beO'
    #pgpassword = utils.getPassword(os.environ['spassword'],os.environ['region'])
    #app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://' + os.environ['suser'] + ':' + pgpassword + '@' + os.environ['shost'] + '/' + os.environ['sdatabase']     
	
    #pgpassword = utils.getPassword(os.environ['spassword'],os.environ['region'])
    app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://' + os.environ['suser'] + ':' + os.environ['spassword'] \
                                            + '@' + os.environ['shost'] + ':' + os.environ['sport'] + '/' + os.environ['sdatabase']
    db.init_app(app)

    login_manager = LoginManager()
    login_manager.login_view = 'auth.login'
    login_manager.init_app(app)

    from .models import User
    from .models import Userinfo

    @login_manager.user_loader
    def load_user(user_id):
        # since the user_id is just the primary key of our user table, use it in the query for the user
        return User.query.get(int(user_id))

    @login_manager.user_loader
    def load_loginUserInfo(user_id):
        # since the user_id is just the primary key of our user table, use it in the query for the user
        return Userinfo.query.get(int(user_id))

    # blueprint for auth routes in our app
    from .auth import auth as auth_blueprint
    app.register_blueprint(auth_blueprint)

    # blueprint for non-auth parts of app
    from .main import main as main_blueprint
    app.register_blueprint(main_blueprint)

    return app
