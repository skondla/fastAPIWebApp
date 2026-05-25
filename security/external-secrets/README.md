# Runtime Secret Management

> **Gap closed:** *Plain Kubernetes secrets — "Database and JWT secrets sit in a
> base64 `Secret` — no external secrets provider."* (PDF slide 22)

The legacy `secret.yaml` manifests stored DB/JWT credentials as base64 `stringData`
— which is **encoding, not encryption**. Anyone with `get secret` RBAC (or read
access to the Git repo where the rendered manifest lands) recovers them in plaintext.

This directory replaces that pattern with two production options.

## Option A — External Secrets Operator (recommended)

[`aws-secret-store.yaml`](aws-secret-store.yaml) defines a `SecretStore` +
`ExternalSecret` per namespace. The [External Secrets Operator](https://external-secrets.io)
pulls live values from **AWS Secrets Manager** and projects them into the
`fastapi-db-secret` Secret the Deployment already consumes via `envFrom`.

```bash
# 1. Install the operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# 2. Store the real values in AWS Secrets Manager (one-time)
aws secretsmanager create-secret --name fastapi/db \
  --secret-string '{"host":"...","port":"5432","user":"...","password":"...","dbname":"flaskapp"}'
aws secretsmanager create-secret --name fastapi/jwt \
  --secret-string '{"secret_key":"'"$(openssl rand -hex 32)"'"}'

# 3. Grant the fastapi-sa IRSA role secretsmanager:GetSecretValue, then apply
kubectl apply -f security/external-secrets/aws-secret-store.yaml
```

The CI deploy step no longer applies a base64 `secret.yaml` — the operator owns
the Secret. Credentials never live in Git, the manifest, or the workflow logs.

For **GKE** use a `SecretStore` with `provider.gcpsm` (Secret Manager) + Workload
Identity; for **AKS** use `provider.azurekv` (Key Vault) + Workload Identity. The
structure is identical — only the `provider` block changes.

## Option B — Sealed Secrets (GitOps-friendly fallback)

If an external secrets manager is not available, [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
lets you commit an **encrypted** `SealedSecret` to Git that only the in-cluster
controller can decrypt:

```bash
kubeseal --fetch-cert > pub-cert.pem
kubectl create secret generic fastapi-db-secret \
  --namespace fastapi-namespace \
  --from-literal=spassword='...' --from-literal=SECRET_KEY='...' \
  --dry-run=client -o yaml \
| kubeseal --cert pub-cert.pem -o yaml > sealed-fastapi-db-secret.yaml
# commit sealed-fastapi-db-secret.yaml — safe, it is asymmetrically encrypted
```

Either option removes plaintext credentials from the repo and the pipeline.
