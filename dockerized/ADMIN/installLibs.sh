#!/bin/bash
# This script installs the required libraries for the project.

pip install fastapi uvicorn sqlalchemy asyncpg
uvicorn init:app --host 0.0.0.0 --port 8000 --reload

pip install fastapi uvicorn sqlalchemy asyncpg passlib bcrypt python-multipart
pip install fastapi uvicorn jinja2 sqlalchemy asyncpg python-multipart
pip install fastapi sqlalchemy asyncpg alembic

#Migrate DB (if using Alembic)
alembic revision --autogenerate -m "Initial migration"
alembic upgrade head

