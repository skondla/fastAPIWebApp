# fastAPIWebApp

[![license](https://img.shields.io/github/license/mashape/apistatus.svg?maxAge=2592000)](https://github.com/skondla/flaskAPIWebApp/blob/main/LICENSE)
[![slack](https://img.shields.io/badge/slack-chat-yellow)](https://join.slack.com/t/devops-zwf1016/shared_invite/zt-1wsafgivm-iI88~ZqZBaKGzYhD8N2JsA)
[![CICD](https://github.com/skondla/flaskAPIWebApp/actions/workflows/Deploy-GKE-flaskAdminApp.yml/badge.svg?event=push)](https://github.com/skondla/flaskAPIWebApp/actions)
[![CICD](https://github.com/skondla/flaskAPIWebApp/actions/workflows/Deploy-GKE-flaskUserApp.yml/badge.svg?event=push)](https://github.com/skondla/flaskAPIWebApp/actions)
[![CICD](https://github.com/skondla/flaskAPIWebApp/actions/workflows/Deploy-EKS-ADMIN.yml/badge.svg?event=push)](https://github.com/skondla/flaskAPIWebApp/actions)
[![CICD](https://github.com/skondla/flaskAPIWebApp/actions/workflows/Deploy-EKS-USER.yml/badge.svg?event=push)](https://github.com/skondla/flaskAPIWebApp/actions)
[![Twitter Follow](https://img.shields.io/twitter/follow/skondla?style=social)](https://twitter.com/skondla)

A multi-cloud, containerized web application and REST API for managing AWS RDS database operations — including restore from snapshot, status monitoring, and cluster attachment. Deployed on Kubernetes (EKS, GKE) with a full DevSecOps pipeline via GitHub Actions and ArgoCD GitOps.

> **Flask → FastAPI Migration** — Both the USER and ADMIN applications have been fully converted from Flask to FastAPI (Python 3.11, Uvicorn, JWT OAuth 2.0, Pydantic v2, OWASP Top 10 middleware). The FastAPI versions live in `dockerized/USER_FASTAPI/` and `dockerized/ADMIN_FASTAPI/`. The original Flask source files in `dockerized/USER/` and `dockerized/ADMIN/` are retained as legacy reference.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Application Structure](#application-structure)
- [API Endpoints](#api-endpoints)
- [Database Schema](#database-schema)
- [Infrastructure](#infrastructure)
- [CI/CD Pipeline](#cicd-pipeline)
- [Getting Started](#getting-started)
- [Usage — cURL Examples](#usage--curl-examples)
- [Screenshots](#screenshots)
- [DevSecOps Pipeline Diagrams](#devsecops-pipeline-diagrams)
- [Contact](#contact)

---

## Overview

The application exposes both a web interface (HTML/Jinja2) and a REST API for the following AWS RDS operations:

1. **Restore** — Restore an AWS RDS instance or Aurora cluster from a snapshot.
2. **Status** — Check the restore progress of a database instance or cluster.
3. **Attach DB** — Attach a new instance to an existing Aurora DB cluster.
4. **Authentication** — JWT-based login/signup with bcrypt password hashing.
5. **Audit Logging** — Every user action is recorded (email, IP, timestamp, endpoint, request type).

Authentication is required for all database operations. User signup is restricted to Admin console users only.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          Client (Browser / cURL)                         │
└──────────────────┬───────────────────────────────┬───────────────────────┘
                   │ HTTPS :50443 / :20443          │ HTTPS :30443 / :17344
                   ▼                                ▼
       ┌───────────────────────┐       ┌────────────────────────┐
       │  USER_FASTAPI App     │       │  ADMIN_FASTAPI App     │
       │  (FastAPI + Jinja2)   │       │  (FastAPI + Jinja2)    │
       │  Python 3.11/Uvicorn  │       │  Python 3.11/Uvicorn   │
       │                       │       │                        │
       │  Routes:              │       │  Routes:               │
       │  /login  /signup      │       │  /login  /signup       │
       │  /restore /status     │       │  /profile  /logout     │
       │  /attachdb /logout    │       │  /auth/token /auth/me  │
       │  /auth/token /auth/me │       │                        │
       └──────────┬────────────┘       └──────────┬─────────────┘
                  │                               │
                  └──────────────┬────────────────┘
                                 │
                  ┌──────────────▼────────────────┐
                  │     PostgreSQL Database        │
                  │  Tables: users, user_info      │
                  │  (Docker container / RDS)      │
                  └──────────────┬────────────────┘
                                 │
                  ┌──────────────▼────────────────┐
                  │         AWS Services           │
                  │  ┌─────────────────────────┐  │
                  │  │  RDS / Aurora           │  │
                  │  │  (Restore, Status,      │  │
                  │  │   Attach via boto3)     │  │
                  │  ├─────────────────────────┤  │
                  │  │  SES (Email alerts)     │  │
                  │  ├─────────────────────────┤  │
                  │  │  ECR (Container images) │  │
                  │  └─────────────────────────┘  │
                  └───────────────────────────────┘

─────────────────── Deployment Targets ─────────────────────

  ┌─────────────────────┐    ┌─────────────────────┐
  │  AWS EKS / ECS      │    │  GCP GKE            │
  │  (us-west-2)        │    │  (us-central1)      │
  │  Terraform modules  │    │  K8s manifests      │
  │  ALB, VPC, NAT GW   │    │  3-replica deploy   │
  └─────────────────────┘    └─────────────────────┘
            │                          │
            └──────────┬───────────────┘
                       │
          ┌────────────▼───────────────┐
          │  ArgoCD (GitOps)           │
          │  GitHub Actions (CI/CD)    │
          │  Trivy (Security scanning) │
          └────────────────────────────┘
```

### Component Interaction

```
GitHub Push
    │
    ▼
GitHub Actions
    ├── Trivy Vulnerability Scan (SARIF → GitHub Security)
    ├── Docker Build & Push → ECR / GCR
    └── Deploy → EKS  or  GKE
                    │
                    ▼
              ArgoCD (GitOps)
                    │
            ┌───────┴────────┐
            ▼                ▼
    K8s Deployment       K8s Service
    (admin-ui x3)        (user-ui)
    (user-ui  x3)        (admin-ui)
```

---

## Technology Stack

### FastAPI Applications (current)

| Layer | ADMIN_FASTAPI | USER_FASTAPI |
|---|---|---|
| Language | Python 3.11 | Python 3.11 |
| Web Framework | **FastAPI** | **FastAPI** |
| ASGI Server | **Uvicorn** | **Uvicorn** |
| Templating | Jinja2 | Jinja2 |
| Authentication | **JWT OAuth 2.0** (python-jose) | **JWT OAuth 2.0** (python-jose) |
| Password Hashing | bcrypt (passlib) + werkzeug fallback | bcrypt (passlib) + werkzeug fallback |
| Schema Validation | **Pydantic v2** | **Pydantic v2** |
| ORM | SQLAlchemy 2.0 | SQLAlchemy 2.0 |
| Database | PostgreSQL (psycopg2) | PostgreSQL (psycopg2) |
| Security | OWASP Top 10 middleware, rate-limiting, security headers | OWASP Top 10 middleware, rate-limiting, security headers |
| AWS SDK | boto3 / botocore | boto3 / botocore |
| HTTP Client | requests | requests |
| Testing | pytest + httpx | pytest + httpx |
| Port | 30443 (HTTPS) | 50443 (HTTPS) |

### Flask Applications (legacy reference)

| Layer | ADMIN (Flask) | USER (Flask) |
|---|---|---|
| Language | Python 3.9 | Python 3.9 |
| Web Framework | Flask | Flask |
| WSGI Server | mod_wsgi (httpd) | mod_wsgi |
| Authentication | Flask-Login | Flask-Login |
| Password Hashing | werkzeug pbkdf2:sha256 | werkzeug pbkdf2:sha256 |
| ORM | Flask-SQLAlchemy | Flask-SQLAlchemy |

### Infrastructure

| Infrastructure | Technology |
|---|---|
| Containerization | Docker (Python 3.11-slim) |
| Orchestration | Kubernetes (EKS, GKE, AKS) |
| IaC | Terraform (modular, AWS) |
| CI/CD | GitHub Actions |
| GitOps | ArgoCD |
| Security Scanning | Trivy (CRITICAL severity) |
| Observability | Prometheus + Grafana (K8s operators) |
| Message Queue | RabbitMQ (K8s operator) |
| Cloud Providers | AWS (primary), GCP, Azure |
| TLS | Self-signed certs (containers) / ACM (AWS ALB) |

---

## Application Structure

```
fastAPIWebApp/
├── dockerized/
│   ├── ADMIN_FASTAPI/            # ✅ FastAPI Admin Portal (converted from ADMIN/)
│   │   ├── main.py               # FastAPI app: middleware, router includes, exception handler
│   │   ├── database.py           # SQLAlchemy 2.0 engine + session factory
│   │   ├── models.py             # ORM: User, Users (SQLAlchemy DeclarativeBase)
│   │   ├── schemas.py            # Pydantic v2: UserCreate, UserResponse, Token
│   │   ├── security.py           # JWT OAuth 2.0: create/decode tokens, bcrypt, dependencies
│   │   ├── security_middleware.py# OWASP Top 10: security headers, rate-limit, audit log
│   │   ├── routers/
│   │   │   ├── auth.py           # /login /signup /logout + /auth/token /auth/me /auth/register
│   │   │   └── main_router.py    # / (index), /profile (protected)
│   │   ├── templates/            # Jinja2 HTML: base, index, login, signup, profile
│   │   ├── Dockerfile            # Python 3.11-slim, Uvicorn, self-signed TLS, port 30443
│   │   ├── startup.sh            # Container entrypoint: sets env vars, starts Uvicorn
│   │   └── requirements.txt      # fastapi, uvicorn, sqlalchemy, passlib, python-jose, ...
│   │
│   ├── USER_FASTAPI/             # ✅ FastAPI User App (converted from USER/)
│   │   ├── main.py               # FastAPI app: middleware, exception handler
│   │   ├── database.py           # SQLAlchemy 2.0 engine + session factory
│   │   ├── models.py             # ORM: User, Userinfo
│   │   ├── schemas.py            # Pydantic v2: UserCreate, Token, RestoreRequest, ...
│   │   ├── security.py           # JWT OAuth 2.0 + werkzeug pbkdf2 migration support
│   │   ├── security_middleware.py# OWASP Top 10 middleware + SSRF endpoint validation
│   │   ├── routers/
│   │   │   ├── auth.py           # /login /signup /logout + OAuth2 API endpoints
│   │   │   └── main_router.py    # / /restore /status /attachdb (RDS ops + audit log)
│   │   ├── lib/
│   │   │   ├── rdsAdmin.py       # RDS: RDSDescribe, RDSCreate, RDSRestore, RDSDelete
│   │   │   └── utils.py          # AWS Secrets Manager helper
│   │   ├── templates/            # Jinja2 HTML: base, login, signup, restore, status, attachdb
│   │   ├── docs/                 # API docs (api.md, architecture.drawio)
│   │   ├── Dockerfile            # Python 3.11-slim, Uvicorn, self-signed TLS, port 50443
│   │   ├── startup.sh            # Container entrypoint
│   │   └── requirements.txt      # fastapi, uvicorn, sqlalchemy, passlib, boto3, ...
│   │
│   ├── ADMIN/                    # ⚠️  Flask Admin (legacy — see ADMIN_FASTAPI/ for FastAPI)
│   │   ├── main.py               # Flask Blueprint: / /profile
│   │   ├── auth.py               # Flask Blueprint: /login /signup /logout
│   │   ├── models.py             # Flask-SQLAlchemy: User, Users
│   │   ├── lib/
│   │   │   ├── rdsAdmin.py       # RDS operations
│   │   │   └── sesAdmin.py       # SES email
│   │   ├── templates/            # Jinja2 HTML (Flask url_for — not compatible with FastAPI)
│   │   ├── Dockerfile            # Python 3.9.13, mod_wsgi, port 30443
│   │   └── requirements.txt      # flask, flask-login, flask-sqlalchemy, ...
│   │
│   ├── USER/                     # ⚠️  Flask User App (legacy — see USER_FASTAPI/ for FastAPI)
│   │   ├── main.py               # Flask Blueprint: / /restore /status /attachdb
│   │   ├── auth.py               # Flask Blueprint: auth + RDS operations
│   │   ├── models.py             # Flask-SQLAlchemy: User, Userinfo
│   │   ├── lib/
│   │   │   ├── rdsAdmin.py       # RDS classes
│   │   │   └── sesAdmin.py       # SES email
│   │   ├── templates/            # Jinja2 HTML (Flask url_for)
│   │   ├── Dockerfile            # Python 3.9.13, port 50443
│   │   └── requirements.txt      # flask, flask-login, flask-sqlalchemy, ...
│   │
│   └── DB/
│       └── schema/
│           └── flaskapp.sql      # PostgreSQL schema: users + user_info tables
│
├── provisioning/
│   └── terraform/aws/web_infra/  # Modular Terraform for AWS
│       ├── main.tf               # Root module, provider config
│       ├── variables.tf          # Input variables
│       ├── outputs.tf            # Output values
│       └── modules/
│           ├── vpc/              # VPC + public/private subnets (us-west-2)
│           ├── nat_gateway/      # NAT gateway for private subnet egress
│           ├── security_groups/  # Inbound/outbound rules
│           ├── alb/              # Application Load Balancer
│           ├── ec2/app/          # App server EC2 instances
│           ├── ec2/bastion/      # Bastion host for SSH access
│           ├── route_tables/     # Route table associations
│           ├── subnets/          # Subnet definitions
│           ├── acm/              # AWS Certificate Manager (TLS)
│           └── vpc-endpoint-s3/  # S3 VPC endpoint (private subnet)
│
├── aws/
│   ├── ecr/                      # ECR repo setup/destroy scripts
│   ├── ecs/                      # ECS task definitions + IAM policies
│   ├── eks/                      # EKS cluster scripts + K8s manifests
│   └── web_infra/                # Additional AWS web infra scripts
│
├── gcp/
│   └── gke/deploy/manifests/flaskapp1/
│       ├── Deployment_admin_ui.yaml   # 3-replica admin deployment
│       ├── Deployment_user_ui.yaml    # User app deployment
│       ├── Service_admin_ui.yaml      # K8s service for admin
│       └── Service_user_ui.yaml       # K8s service for user
│
├── kubernetes/
│   └── operators/                # Grafana, Prometheus, RabbitMQ operators
│
├── argocd/                       # Helm-based ArgoCD install + ingress config
│
├── actions/
│   ├── Deploy-GKE.yml            # GKE DevSecOps pipeline (test → build → deploy)
│   ├── google.yml                # GCP-specific workflow
│   └── trivy-scan.yaml           # Trivy CRITICAL vulnerability scanning → SARIF
│
└── images/                       # Documentation screenshots
```

---

## API Endpoints

### USER_FASTAPI (port `50443`)

#### Web UI (HTML, cookie-based JWT)

| Method | Endpoint | Auth Required | Description |
|---|---|---|---|
| `GET` | `/` | No | Landing page |
| `GET` | `/login` | No | Login form |
| `POST` | `/login` | No | Authenticate; sets JWT HttpOnly cookie |
| `GET` | `/signup` | No | Signup form |
| `POST` | `/signup` | No | Create account (bcrypt-hashed password) |
| `GET` | `/logout` | No | Clear auth cookies, redirect to `/login` |
| `GET` | `/restore` | Yes | Restore DB form |
| `POST` | `/restore` | Yes | Restore RDS instance or Aurora cluster from snapshot |
| `GET` | `/status` | Yes | Status check form |
| `POST` | `/status` | Yes | Poll RDS restore / instance status |
| `GET` | `/attachdb` | Yes | Attach DB form |
| `POST` | `/attachdb` | Yes | Create and attach instance to Aurora cluster |

#### OAuth2 / REST API (JSON, Bearer token)

| Method | Endpoint | Auth Required | Description |
|---|---|---|---|
| `POST` | `/auth/token` | No | OAuth2 password flow — returns access + refresh tokens |
| `POST` | `/auth/refresh` | No (refresh cookie) | Exchange refresh token for new access token |
| `GET` | `/auth/me` | Yes | Return current user profile |
| `POST` | `/auth/register` | No | Register new user (API, returns JSON) |
| `GET` | `/api/docs` | No | Swagger UI |
| `GET` | `/api/redoc` | No | ReDoc |

### ADMIN_FASTAPI (port `30443`)

#### Web UI (HTML, cookie-based JWT)

| Method | Endpoint | Auth Required | Description |
|---|---|---|---|
| `GET` | `/` | No | Admin portal landing page |
| `GET` | `/login` | No | Admin login form |
| `POST` | `/login` | No | Authenticate; sets JWT HttpOnly cookie |
| `GET` | `/signup` | No | Admin signup form |
| `POST` | `/signup` | No | Create admin account |
| `GET` | `/logout` | No | Clear auth cookies |
| `GET` | `/profile` | Yes | Authenticated admin profile page |

#### OAuth2 / REST API (JSON, Bearer token)

| Method | Endpoint | Auth Required | Description |
|---|---|---|---|
| `POST` | `/auth/token` | No | OAuth2 password flow |
| `POST` | `/auth/refresh` | No (refresh cookie) | Refresh access token |
| `GET` | `/auth/me` | Yes | Return current admin profile |
| `POST` | `/auth/register` | No | Register admin user (API, returns JSON) |
| `GET` | `/api/docs` | No | Swagger UI |
| `GET` | `/api/redoc` | No | ReDoc |

---

## Database Schema

PostgreSQL, managed via SQLAlchemy ORM. The `flaskapp.sql` bootstrap file creates:

```sql
-- Registered users
CREATE TABLE users (
    id       SERIAL PRIMARY KEY,
    email    VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(1000) NOT NULL,   -- bcrypt hash
    name     VARCHAR(1000) NOT NULL
);

-- Audit / activity log
CREATE TABLE user_info (
    id          SERIAL PRIMARY KEY,
    email       VARCHAR(100) NOT NULL,
    ip          VARCHAR(50)  NOT NULL,  -- real IP via X-Forwarded-For
    time        VARCHAR(60)  NOT NULL,  -- YYYYMMDDHHmm
    requesttype VARCHAR(30),            -- GET / POST
    endpoint    VARCHAR(100),           -- e.g. /restore
    comments    VARCHAR(200)
);
```

---

## Infrastructure

### AWS — Terraform Modules (`provisioning/terraform/aws/web_infra/`)

| Module | Purpose |
|---|---|
| `vpc` | VPC + public & private subnets across AZs (us-west-2) |
| `nat_gateway` | NAT GW for private subnet internet egress |
| `security_groups` | ALB and app-tier security groups |
| `alb` | Application Load Balancer (HTTPS listener, target groups) |
| `acm` | TLS certificate via AWS Certificate Manager |
| `ec2/app` | Application EC2 instances in private subnet |
| `ec2/bastion` | Bastion host in public subnet for SSH tunneling |
| `route_tables` | Route table associations for public/private subnets |
| `subnets` | Subnet CIDR definitions |
| `vpc-endpoint-s3` | S3 VPC endpoint for private subnet connectivity |

### AWS Container Deployments

- **ECR** — Private container registry for Docker images.
- **ECS** — Fargate task definitions + IAM execution roles.
- **EKS** — Managed Kubernetes; cluster creation/teardown via bash scripts in `aws/eks/`.

### GCP — GKE (`gcp/gke/`)

- Kubernetes manifests for Admin (3 replicas) and User (configurable) deployments.
- `flaskapp1.yaml` — combined manifest.
- LoadBalancer services expose apps externally.

### Kubernetes Operators (`kubernetes/operators/`)

| Operator | Purpose |
|---|---|
| Prometheus | Metrics collection |
| Grafana | Metrics dashboards |
| RabbitMQ | Message queue (for async RDS operations) |

### ArgoCD GitOps (`argocd/`)

- Helm-based ArgoCD installation scripts.
- Ingress configuration for ArgoCD UI.
- Enables automated sync from Git to cluster state.

---

## CI/CD Pipeline

### GitHub Actions Workflows (`actions/`)

#### `Deploy-GKE.yml` — GKE DevSecOps Pipeline

Triggers on push to `testing_on_gcp` or `master` branches.

```
Push to branch
    │
    ├── [Test]      Run pytest unit tests
    ├── [Scan]      Trivy filesystem scan (CRITICAL) → SARIF upload
    ├── [Build]     Docker build + push to GCR
    └── [Deploy]    kubectl apply → GKE (admin-ui + user-ui deployments)
```

#### `Deploy-EKS-ADMIN.yml` / `Deploy-EKS-USER.yml` — EKS Pipelines

Similar stages targeting AWS EKS with ECR as the image registry.

#### `trivy-scan.yaml` — Standalone Security Scan

- Trivy filesystem vulnerability scanning on every PR.
- Severity filter: `CRITICAL`.
- Results uploaded as SARIF to GitHub Security tab.

---

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Python 3.9+
- AWS credentials configured (`~/.aws/credentials` or environment variables)
- PostgreSQL (or use the included DB container)

### Run with Docker

```bash
# Build and start all services (USER app, ADMIN app, PostgreSQL)
cd dockerized

# USER app (HTTPS on port 50443)
docker build -t fastapi-user ./USER
docker run -p 50443:50443 --env-file USER/env.sh fastapi-user

# ADMIN app (HTTPS on port 30443)
docker build -t flask-admin ./ADMIN
docker run -p 30443:30443 --env-file ADMIN/env.sh flask-admin
```

### Environment Variables

Both apps expect these variables (see `env.sh` in each app directory):

```bash
DB_HOST=<postgres-host>
DB_PORT=5432
DB_NAME=flaskapp
DB_USER=<db-user>
DB_PASSWORD=<db-password>
AWS_DEFAULT_REGION=us-east-1
AWS_ACCESS_KEY_ID=<key>
AWS_SECRET_ACCESS_KEY=<secret>
SECRET_KEY=<jwt-secret>
```

### Initialize the Database

```bash
psql -h <host> -U <user> -d flaskapp -f dockerized/DB/schema/flaskapp.sql
```

---

## Usage — cURL Examples

### Restore a DB from Snapshot

```bash
#!/bin/bash
# Restore RDS instance from snapshot

snapshotname=${1}   # e.g. my-snapshot-name
endpoint=${2}       # e.g. myDB.cluster-XXXYYY.us-east-1.rds.amazonaws.com

EMAIL=$(cat ~/.password/mySecrets2 | grep email | awk '{print $2}')
PASSWORD=$(cat ~/.password/mySecrets2 | grep password | awk '{print $2}')

# Login (stores JWT cookie)
curl -k "https://192.168.2.15:50443/login" \
    --data-urlencode "email=${EMAIL}" \
    --data-urlencode "password=${PASSWORD}" \
    --cookie-jar cookies.txt --verbose > login_log.html

# Trigger restore
curl -k "https://192.168.2.15:50443/restore" \
    --data-urlencode "snapshotname=${snapshotname}" \
    --data-urlencode "endpoint=${endpoint}" \
    --cookie cookies.txt --cookie-jar cookies.txt --verbose
    echo

rm -f cookies.txt
```

### Check Restore Status

```bash
#!/bin/bash
snapshotname=${1}
endpoint=${2}

EMAIL=$(cat ~/.password/mySecrets2 | grep email | awk '{print $2}')
PASSWORD=$(cat ~/.password/mySecrets2 | grep password | awk '{print $2}')

curl -k "https://192.168.2.15:50443/login" \
    --data-urlencode "email=${EMAIL}" \
    --data-urlencode "password=${PASSWORD}" \
    --cookie-jar cookies.txt --verbose > login_log.html

curl -k "https://192.168.2.15:50443/status" \
    --data-urlencode "snapshotname=${snapshotname}" \
    --data-urlencode "endpoint=${endpoint}" \
    --cookie cookies.txt --cookie-jar cookies.txt --verbose
    echo

rm -f cookies.txt
```

### Attach DB Instance to Cluster

```bash
#!/bin/bash
endpoint=${1}       # e.g. myDB.cluster-XXXYYY.us-east-1.rds.amazonaws.com
instanceclass=${2}  # e.g. db.t3.medium

EMAIL=$(cat ~/.password/mySecrets2 | grep email | awk '{print $2}')
PASSWORD=$(cat ~/.password/mySecrets2 | grep password | awk '{print $2}')

curl -k "https://192.168.2.15:50443/login" \
    --data-urlencode "email=${EMAIL}" \
    --data-urlencode "password=${PASSWORD}" \
    --cookie-jar cookies.txt --verbose > login_log.html

curl -k "https://192.168.2.15:50443/attachdb" \
    --data-urlencode "endpoint=${endpoint}" \
    --data-urlencode "instanceclass=${instanceclass}" \
    --cookie cookies.txt --cookie-jar cookies.txt --verbose
    echo

rm -f cookies.txt
```

---

## Screenshots

Sign Up page:

![Alt text](images/signup.png)

Sign In page:

![Alt text](images/signin.png)

RestoreDB page:

![Alt text](images/restore.png)

RestoreDB Status page:

![Alt text](images/restore_status.png)

AttachDB page 1:

![Alt text](images/attachdb1.png)

AttachDB page 2:

![Alt text](images/attachdb2.png)

DB Restore Options after login:

![Alt text](images/db_restore_options_after_login.png)

---

## DevSecOps Pipeline Diagrams

### AKS (Azure Kubernetes Service)
![Alt text](images/DevSecOps_with_GutHub_Actions_AKS.png)

### EKS (AWS Elastic Kubernetes Service)
![Alt text](images/DevSecOps_with_GutHub_Actions_EKS.png)

### GKE (Google Kubernetes Engine)
![Alt text](images/DevSecOps_with_GutHub_Actions_GKE.png)

---

## Contact

###### skondla.ai@gmail.com

###### DevSecOps Blog Posts

[DevSecOps — Deploying WebApp on Azure AKS cluster with Github Actions](https://kondlawork.medium.com/devsecops-deploying-webapp-on-azure-aks-cluster-with-github-actions-efc72bdc552a)

[DevSecOps — Deploying WebApp on AWS EKS cluster with Github Actions](https://kondlawork.medium.com/devsecops-deploying-webapp-on-aws-eks-cluster-with-github-actions-da8865a1b27)

[DevSecOps — Deploying WebApp on Google Cloud GKE cluster with Github Actions](https://medium.com/@kondlawork/devsecops-deploying-webapp-on-google-cloud-gke-cluster-with-github-actions-1028c0630dde)
