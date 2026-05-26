# Module: aws-hub-vpc

Hub VPC for the AWS side of the multi-cloud topology. Lives in `us-east-1` by default.

## What it builds
- VPC with DNS hostnames + support
- 3× public, 3× private, 3× data subnets across 3 AZs (sized off CIDR via `cidrsubnet`)
- IGW + 3 NAT GWs (per-AZ, no cross-AZ data-transfer charges on egress)
- Public, private, and data route tables
- Default SG / default NACL locked down (deny-all baseline, must use explicit SGs/NACLs)
- VPC Flow Logs → CloudWatch (90d minimum, KMS-encrypted log group)
- VPC interface endpoints for ECR, STS, KMS, Secrets Manager, EC2, SSM, ELB, Logs
- S3 gateway endpoint attached to private + data route tables
- Transit Gateway (single hub) with a dedicated route table — opt-out via `enable_transit_gateway = false`

## Guardrails enforced inside the module
- `flow_logs_retention_days >= 90` (SOC2 / PCI forensics window)
- Exactly 3 AZs (no single-AZ "demo" deployments)
- Default SG/NACL replaced with deny-all (no implicit allow-all)
- TGW ASN must be private (64512-65534) and unique per cloud
- No public IPs auto-assigned (`map_public_ip_on_launch = false`)
- Flow log CloudWatch group is KMS-encrypted with key-rotation enabled

## Inputs
See `variables.tf`. All variables have descriptions and most have validations.

## Outputs
- `vpc_id`, `vpc_cidr`
- `public_subnet_ids`, `private_subnet_ids`, `data_subnet_ids`
- `transit_gateway_id`, `transit_gateway_route_table_id` (null when TGW disabled)
- `flow_log_group_arn`
- `vpc_endpoint_security_group_id`

## Wiring
Downstream modules — `aws-spoke-vpc`, `aws-azure-vpn`, `aws-gcp-vpn` — consume
`transit_gateway_id` and `transit_gateway_route_table_id` to attach themselves
to the hub.
