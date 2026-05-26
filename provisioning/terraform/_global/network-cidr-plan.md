# Multi-cloud CIDR plan

Every CIDR below MUST be non-overlapping. Cross-cloud routes are populated as
static fallback routes on each hub — overlap silently blackholes traffic.

## RFC 1918 allocation (10.0.0.0/8)

| Cloud  | Tier    | Env    | CIDR             | Notes                                |
|--------|---------|--------|------------------|--------------------------------------|
| AWS    | hub     | shared | `10.10.0.0/16`   | TGW + shared services                |
| AWS    | spoke   | prod   | `10.20.0.0/16`   | EKS prod workloads                   |
| AWS    | spoke   | nonprod| `10.30.0.0/16`   | EKS nonprod                          |
| Azure  | hub     | shared | `10.40.0.0/16`   | Firewall + VPN GW + shared services  |
| Azure  | spoke   | prod   | `10.50.0.0/16`   | AKS prod                             |
| Azure  | spoke   | nonprod| `10.60.0.0/16`   | AKS nonprod                          |
| GCP    | hub     | shared | `10.70.0.0/16`   | Shared VPC + HA VPN + Cloud Router   |
| GCP    | spoke   | prod   | `10.80.0.0/16`   | GKE prod (subnets)                   |
| GCP    | spoke   | nonprod| `10.90.0.0/16`   | GKE nonprod                          |

## CGNAT (100.64.0.0/10) — Kubernetes pods only

Pods consume CIDR fast. Keeping pods in CGNAT space leaves RFC1918 free for
VMs/PaaS and avoids cross-cloud overlap concerns (pods aren't routed across).

| Cloud  | Purpose         | CIDR              |
|--------|-----------------|-------------------|
| AWS    | EKS pods (CNI)  | `100.64.0.0/14`   |
| Azure  | AKS pods        | `100.68.0.0/14`   |
| GCP    | GKE pods        | `100.72.0.0/14`   |
| GCP    | GKE services    | `100.76.0.0/16`   |

## BGP ASN allocation (64512-65534)

ASNs MUST be unique per autonomous system. Re-use causes BGP loop-prevention to drop routes.

| Cloud  | Component                              | ASN     |
|--------|----------------------------------------|---------|
| AWS    | Transit Gateway (Amazon-side)          | 64512   |
| Azure  | Virtual Network Gateway                | 65515   |
| GCP    | Cloud Router (HA VPN BGP)              | 65530   |

## Reserved blocks (do not use)
- `10.0.0.0/16`, `10.1.0.0/16` — legacy EKS terraform demos in `aws/eks/`
- `192.168.0.0/16` — legacy EKS terraform demo
- `169.254.0.0/16` — link-local (used for BGP APIPA peering inside tunnels)

## Allocation rules
1. Every new VPC/VNet must come back to this table for a /16 assignment.
2. /16 minimum at the VPC level; subnets are carved with `cidrsubnet()`.
3. No CIDR re-use across regions even within the same cloud.
4. Pod CIDRs stay in CGNAT; they are NOT advertised over the cross-cloud mesh.
