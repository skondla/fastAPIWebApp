# Security Posture & Remediation

This document tracks the security gaps identified in the **DevSecOps Pipeline,
Infrastructure & Kubernetes analysis** of `skondla/fastAPIWebApp` (Dashboard
Edition) and the concrete changes made in this repository to close them.

The analysis verdict was: *"comprehensive scanning, keyless cloud authentication,
least-privilege pipeline permissions, and a hardened Kubernetes runtime. Its one
defining limitation: every security stage reports findings without ever blocking
the build."* The remediation below turns the pipeline from **observe** to
**enforce**, adds **supply-chain integrity**, fixes **runtime secret storage**,
and adds **policy-as-code**.

---

## Remediation summary — weaknesses (PDF slide 22)

| # | Gap (slide 22) | Status | What changed |
|---|----------------|--------|--------------|
| 1 | **Non-blocking security gates** — scanners report, none fail the build | ✅ Fixed | Every workflow now has **blocking gates**: secret-scan (TruffleHog/GitLeaks fail by default), Bandit (`--severity-level high --confidence-level high`, no `\|\| true`), Semgrep (`--error --severity ERROR`), pip-audit (non-zero on any vuln), Trivy FS + image (`severity: CRITICAL`, `exit-code: "1"`), Checkov K8s (`soft_fail: false`). Full HIGH+CRITICAL SARIF still uploads for visibility via `if: always()`. |
| 2 | **Push / pull duality** — pipeline `kubectl apply` *and* ArgoCD reconcile | ✅ Fixed | [`argocd/applications/`](argocd/applications/) makes ArgoCD the single delivery authority (`selfHeal`, `prune`). The pipeline builds/scans/signs/pushes and bumps the image tag; ArgoCD reconciles. See [argocd/applications/README.md](argocd/applications/README.md). |
| 3 | **DAST credential gap** — DAST resolved the LB without re-auth | ✅ Fixed | Every `dast` job now re-authenticates (AWS OIDC / GCP WIF / Azure OIDC) and refreshes kube-context before `kubectl get svc`. |
| 4 | **Plain Kubernetes secrets** — base64 `Secret`, no external provider | ✅ Fixed | [`security/external-secrets/`](security/external-secrets/) adds External Secrets Operator (`SecretStore` + `ExternalSecret` → AWS Secrets Manager) with a Sealed Secrets fallback. Plaintext credentials leave Git and the pipeline. |
| 5 | **No supply-chain integrity** — no signing, SBOM, or attestation | ✅ Fixed | Every `build` job signs the image with **cosign keyless** (OIDC + Fulcio + Rekor), generates a **CycloneDX SBOM** (Syft), and records a **cosign SBOM attestation**. `container-scan` verifies the signature; Kyverno verifies it again at admission. |
| 6 | **No policy-as-code** — no admission control, no concurrency guard | ✅ Fixed | [`security/kyverno/`](security/kyverno/) adds admission ClusterPolicies (signature verify, pod-security restricted, supply-chain hygiene). Every workflow has a `concurrency:` guard preventing overlapping deploys. |

## Remediation summary — control status (PDF slide 20) & K8s hardening (slide 14)

| Control | Before | After |
|---------|--------|-------|
| Enforcing security gates | 0/8 | **8/8** — all scanners block |
| Image signing / SBOM | ABSENT | **cosign keyless + CycloneDX SBOM + attestation** |
| Policy-as-code admission | ABSENT | **Kyverno ClusterPolicies (Enforce)** |
| Runtime secret storage | PLAIN SECRET | **External Secrets Operator / Sealed Secrets** |
| Read-only root filesystem | not evidenced | **`readOnlyRootFilesystem: true`** on all 6 deployments + emptyDir `/tmp`,`/app/tmp` |
| NetworkPolicy / Pod Security | not evidenced | **default-deny NetworkPolicies** + namespace PSS labels (already present) |

---

## Phase mapping (PDF roadmap, slide 25)

- **Phase 1 · Enforce** — gates now block (secret-scan, SAST high-confidence,
  Trivy CRITICAL, pip-audit, Checkov K8s).
- **Phase 2 · Harden** — single delivery model via ArgoCD; cosign image signing +
  SBOM; External Secrets Operator.
- **Phase 3 · Govern** — Kyverno policy-as-code admission control; Checkov K8s
  hard-fail; DAST runs with valid credentials; concurrency guards.

---

## How to apply the cluster-side controls

```bash
# 1. Install the admission + supply-chain controllers
helm repo add kyverno https://kyverno.github.io/kyverno && helm install kyverno kyverno/kyverno -n kyverno --create-namespace
helm repo add external-secrets https://charts.external-secrets.io && helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace

# 2. Apply policies, network policies, and external secrets
kubectl apply -f security/kyverno/
kubectl apply -f security/network-policies/
kubectl apply -f security/external-secrets/aws-secret-store.yaml

# 3. Make ArgoCD the single delivery authority
kubectl apply -f argocd/applications/
```

## CI prerequisites (already wired into the workflows)

- `id-token: write` for OIDC keyless cosign signing (no static signing keys).
- `packages: write` to push cosign signatures / attestations.
- Trusted signer identity is locked to
  `https://github.com/skondla/fastAPIWebApp/.github/workflows/*` via the
  `token.actions.githubusercontent.com` issuer — both in the `cosign verify`
  step and the Kyverno `verifyImages` policy.

## Reporting a vulnerability

Email **skondla.ai@gmail.com** with details and reproduction steps. Please do
not open a public issue for undisclosed vulnerabilities.
