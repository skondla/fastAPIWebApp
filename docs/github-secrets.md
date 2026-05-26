# GitHub Actions — Required Secrets & Variables

Configure these in **Settings → Secrets and variables → Actions** of your GitHub repository.

---

## Secrets common to all three pipelines

| Secret | Description | Example |
|--------|-------------|---------|
| `JWT_SECRET_KEY` | JWT signing key — must be long, random, unique per environment | `openssl rand -hex 32` |
| `SLACK_WEBHOOK_URL` | Slack incoming-webhook URL for deploy notifications | `https://hooks.slack.com/services/T.../B.../...` |
| `DB_PASSWORD` | PostgreSQL password injected into the K8s Secret manifest | — |
| `ANTHROPIC_API_KEY` | Claude API key for the AI Security Triage agent (`ai-triage` job). Optional — the advisory job skips cleanly if unset. | `sk-ant-...` |

---

## AWS EKS — `devsecops-fastapi-eks.yml`

### Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ROLE_ARN` | IAM Role ARN for GitHub OIDC authentication (no long-lived keys) |

### Setup: AWS OIDC trust

```bash
# 1. Create OIDC provider for GitHub in IAM (one-time per account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2. Create IAM Role with this trust policy (replace ORG/REPO):
# {
#   "Effect": "Allow",
#   "Principal": {"Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"},
#   "Action": "sts:AssumeRoleWithWebIdentity",
#   "Condition": {
#     "StringLike": {"token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:*"},
#     "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"}
#   }
# }
# Attach policies: AmazonEKSClusterPolicy, AmazonEC2ContainerRegistryPowerUser

# 3. Set secret
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::<ACCOUNT_ID>:role/<ROLE_NAME>"
```

### Workflow variables (edit directly in the yml)

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region |
| `EKS_CLUSTER` | `fastapi-demo-cluster` | EKS cluster name |
| `ECR_REPOSITORY` | `fastapi-user-app` | ECR repository name |
| `EKS_NAMESPACE` | `fastapi-namespace` | Kubernetes namespace |

---

## Azure AKS — `devsecops-fastapi-aks.yml`

### Secrets

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | App Registration client ID (for OIDC Workload Identity) |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

### Setup: Azure OIDC Workload Identity

```bash
# 1. Create App Registration
az ad app create --display-name "github-actions-fastapi"

# 2. Create Service Principal
az ad sp create --id <APP_ID>

# 3. Add Federated Credential (replace ORG/REPO/BRANCH)
az ad app federated-credential create \
  --id <APP_ID> \
  --parameters '{
    "name": "github-actions",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<ORG>/<REPO>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# 4. Assign roles
az role assignment create \
  --assignee <APP_ID> \
  --role "Contributor" \
  --scope /subscriptions/<SUBSCRIPTION_ID>

# 5. Set secrets
gh secret set AZURE_CLIENT_ID       --body "<APP_ID>"
gh secret set AZURE_TENANT_ID       --body "<TENANT_ID>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<SUBSCRIPTION_ID>"
```

### Workflow variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AZURE_RESOURCE_GROUP` | `fastapi-rg` | Resource group name |
| `AKS_CLUSTER` | `fastapi-aks-cluster` | AKS cluster name |
| `ACR_NAME` | `fastapiregistry` | Azure Container Registry name (globally unique) |
| `AKS_NAMESPACE` | `fastapi-namespace` | Kubernetes namespace |

---

## GCP GKE — `devsecops-fastapi-gke.yml`

### Secrets

| Secret | Description |
|--------|-------------|
| `GKE_PROJECT` | GCP project ID |
| `GKE_SA` | GCP Service Account email used as Workload Identity annotation |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Workload Identity Provider resource name |
| `GCP_SERVICE_ACCOUNT` | GCP Service Account email for GitHub Actions OIDC |

### Setup: GCP Workload Identity Federation

```bash
# 1. Enable APIs
gcloud services enable \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com

# 2. Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --project="${GCP_PROJECT}" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# 3. Create OIDC Provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${GCP_PROJECT}" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# 4. Create Service Account
gcloud iam service-accounts create "github-actions-sa" \
  --project="${GCP_PROJECT}" \
  --display-name="GitHub Actions Service Account"

# 5. Bind roles
gcloud projects add-iam-policy-binding "${GCP_PROJECT}" \
  --member="serviceAccount:github-actions-sa@${GCP_PROJECT}.iam.gserviceaccount.com" \
  --role="roles/container.developer"
gcloud projects add-iam-policy-binding "${GCP_PROJECT}" \
  --member="serviceAccount:github-actions-sa@${GCP_PROJECT}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

# 6. Allow GitHub to impersonate the SA (replace ORG/REPO)
gcloud iam service-accounts add-iam-policy-binding \
  "github-actions-sa@${GCP_PROJECT}.iam.gserviceaccount.com" \
  --project="${GCP_PROJECT}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-pool/attribute.repository/<ORG>/<REPO>"

# 7. Set secrets
PROVIDER="projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
gh secret set GKE_PROJECT                    --body "${GCP_PROJECT}"
gh secret set GKE_SA                         --body "github-actions-sa@${GCP_PROJECT}.iam.gserviceaccount.com"
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body "${PROVIDER}"
gh secret set GCP_SERVICE_ACCOUNT           --body "github-actions-sa@${GCP_PROJECT}.iam.gserviceaccount.com"
```

### Workflow variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GKE_CLUSTER` | `fastapi-demo-cluster` | GKE cluster name |
| `GKE_REGION` | `us-east4` | GCP region |
| `GKE_ZONE` | `us-east4-a` | GCP zone for zonal cluster |
| `GKE_NAMESPACE` | `fastapi-namespace` | Kubernetes namespace |

---

## Setting all secrets at once

```bash
# Prerequisites: GitHub CLI (gh) authenticated, terraform outputs available

# Common
gh secret set JWT_SECRET_KEY    --body "$(openssl rand -hex 32)"
gh secret set SLACK_WEBHOOK_URL --body "<your-slack-webhook>"
gh secret set DB_PASSWORD       --body "<your-db-password>"

# AWS
gh secret set AWS_ROLE_ARN --body "arn:aws:iam::<ACCOUNT>:role/<ROLE>"

# Azure
gh secret set AZURE_CLIENT_ID       --body "<client-id>"
gh secret set AZURE_TENANT_ID       --body "<tenant-id>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<subscription-id>"

# GCP
gh secret set GKE_PROJECT                    --body "<project-id>"
gh secret set GKE_SA                         --body "<sa@project.iam.gserviceaccount.com>"
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER --body "projects/<num>/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
gh secret set GCP_SERVICE_ACCOUNT           --body "<sa@project.iam.gserviceaccount.com>"
```

---

## K8s Secret manifest (auto-generated by workflow)

The `secret.yaml` manifests use `envsubst` substitution. The following environment variables
must be present in the GitHub Actions runner environment (sourced from secrets):

| Manifest variable | GitHub Secret / env var |
|-------------------|------------------------|
| `${JWT_SECRET_KEY}` | `secrets.JWT_SECRET_KEY` |
| `${DB_PASSWORD}` | `secrets.DB_PASSWORD` |

Add these to the deploy step `env:` block in each workflow if not already present:

```yaml
env:
  FASTAPI_IMAGE: ${{ needs.build.outputs.image }}
  JWT_SECRET_KEY: ${{ secrets.JWT_SECRET_KEY }}
  DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
```

---

## GitHub Environments (recommended)

Create **`staging`** and **`production`** environments in **Settings → Environments**:

- **staging**: Auto-deploy on every merge to `main`
- **production**: Require manual approval + 1 reviewer before deploy
- Set environment-specific secrets (different DB passwords, JWT keys per environment)
