# IaC guardrails

Three layers of automated checks against this Terraform tree. Run them locally
via pre-commit and centrally in CI.

## Layer 1 — Terraform native
- `terraform fmt -check -recursive` — style consistency
- `terraform validate` per env directory — provider + syntax
- `terraform plan` against `terraform.tfvars.example` — runtime validation
- `tflint` — extended lint (deprecations, naming, module structure)

## Layer 2 — Security scanning
- `tfsec` (config: `tfsec/.tfsec/config.yml`) — built-in rules
- `checkov` (config: `checkov/.checkov.yaml`) — broader CIS / NIST coverage
- `terraform-compliance` — BDD-style policy assertions (optional)

## Layer 3 — Custom policy (Conftest / OPA)
Custom Rego in `conftest/policy/` enforces project-specific rules that off-the-
shelf scanners cannot express:

- `cidr.rego` — no CIDR overlap across clouds, no IPv4 outside the assigned table
- `tagging.rego` — every resource carries the standard tag set
- `encryption.rego` — KMS / CMK required for state-relevant resources
- `network.rego` — no `0.0.0.0/0` ingress, no IKEv1, no SHA1, no DH<14
- `cost.rego` — TGW/VWAN/Firewall require an explicit cost-center tag

## Tooling versions
Pinned in `.pre-commit-config.yaml` at the repo root. CI uses the same image
shas. Drift between local and CI is treated as a bug.

## Running locally

```bash
# install
brew install terraform tflint tfsec checkov conftest pre-commit

# from repo root
pre-commit install
pre-commit run --all-files
```

CI fails the build on any guardrail violation. Don't bypass with
`--no-verify` — fix the violation or extend the policy with a documented
exemption.
