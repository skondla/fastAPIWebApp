#!/bin/bash
# Author: skondla@me.com
# Purpose: Start FastAPI DB Restore Management Tool with Uvicorn (HTTPS)

# ── Environment variables ──────────────────────────────────────────────────────
# Override these at container runtime (-e flag or Kubernetes secret)
export shost="${shost:-localhost}"
export sport="${sport:-5432}"
export suser="${suser:-skondla}"
export spassword="${spassword:-changeme}"
export sdatabase="${sdatabase:-flaskapp}"

# JWT secret — MUST be changed in production
export SECRET_KEY="${SECRET_KEY:-s3dgMHEPR47DlmXNmb9hvHfj99U53beO-CHANGE-IN-PRODUCTION}"

# ── Derive host IP (same pattern as original Flask startup) ───────────────────
HOST_IP=$(hostname -i 2>/dev/null || echo "0.0.0.0")

SSL_CERT=/app/certs/certificate.pem
SSL_KEY=/app/certs/key.pem

echo "Starting FastAPI DB Restore Tool on https://${HOST_IP}:50443"
echo "  DB host:     ${shost}:${sport}/${sdatabase}"
echo "  Swagger UI:  https://${HOST_IP}:50443/api/docs"

# Log to a writable mount so the container root filesystem can stay read-only.
# Kubernetes captures stdout regardless; the file copy goes to the emptyDir at
# /app/tmp (see deployment volumeMounts). Falls back to stdout-only if unset.
LOG_DIR="${LOG_DIR:-/app/tmp}"
mkdir -p "${LOG_DIR}" 2>/dev/null || true

exec uvicorn main:app \
    --host "${HOST_IP}" \
    --port 50443 \
    --ssl-certfile "${SSL_CERT}" \
    --ssl-keyfile  "${SSL_KEY}" \
    --workers 2 \
    --log-level info \
    2>&1 | tee "${LOG_DIR}/fastapi_user.log"
