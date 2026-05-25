#!/bin/bash
# Author: skondla@me.com
# Purpose: Start FastAPI Admin Portal with Uvicorn (HTTPS)

export shost="${shost:-localhost}"
export sport="${sport:-5432}"
export suser="${suser:-skondla}"
export spassword="${spassword:-changeme}"
export sdatabase="${sdatabase:-flaskapp}"

# JWT secret — MUST be changed in production
export SECRET_KEY="${SECRET_KEY:-9OLWxND4o83j4K4iuopO-CHANGE-IN-PRODUCTION}"

HOST_IP=$(hostname -i 2>/dev/null || echo "0.0.0.0")

SSL_CERT=/app/certs/certificate.pem
SSL_KEY=/app/certs/key.pem

echo "Starting FastAPI Admin Portal on https://${HOST_IP}:30443"
echo "  DB host:     ${shost}:${sport}/${sdatabase}"
echo "  Swagger UI:  https://${HOST_IP}:30443/api/docs"

# Log to a writable mount so the container root filesystem can stay read-only.
LOG_DIR="${LOG_DIR:-/app/tmp}"
mkdir -p "${LOG_DIR}" 2>/dev/null || true

exec uvicorn main:app \
    --host "${HOST_IP}" \
    --port 30443 \
    --ssl-certfile "${SSL_CERT}" \
    --ssl-keyfile  "${SSL_KEY}" \
    --workers 2 \
    --log-level info \
    2>&1 | tee "${LOG_DIR}/fastapi_admin.log"
