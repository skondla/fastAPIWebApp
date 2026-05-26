# Multi-cloud network architecture

This document is the source of truth for how AWS, Azure, and GCP environments
are wired together. The Mermaid diagrams below render directly on GitHub.

Diagrams included:

1. **Topology** — physical layout of hubs, spokes, and cross-cloud links.
2. **Traffic flow** — how a request from internet → app → cross-cloud DB
   actually moves.
3. **Security zones** — trust boundaries, NSG/SG enforcement points, egress
   inspection.
4. **BGP / ASN map** — which side originates what, which fail-over paths exist.
5. **State-and-secret topology** — where Terraform state lives, how PSKs flow.

---

## 1. Topology (default: full-mesh IPsec)

```mermaid
flowchart TB
    subgraph AWS["AWS — us-east-1"]
        direction TB
        AWSHub["Hub VPC<br/>10.10.0.0/16<br/>TGW ASN 64512"]
        AWSProd["Prod Spoke VPC<br/>10.20.0.0/16<br/>EKS workloads"]
        AWSHub -.TGW.- AWSProd
    end

    subgraph Azure["Azure — eastus2"]
        direction TB
        AzHub["Hub VNet<br/>10.40.0.0/16<br/>VPN GW ASN 65515<br/>Azure Firewall Premium"]
        AzProd["Prod Spoke VNet<br/>10.50.0.0/16<br/>AKS workloads"]
        AzHub <-.peering.-> AzProd
    end

    subgraph GCP["GCP — us-east4"]
        direction TB
        GCPHub["Shared VPC host<br/>10.70.0.0/16<br/>Router ASN 65530<br/>HA VPN GW"]
        GCPProd["Service project<br/>10.80.0.0/20<br/>GKE workloads"]
        GCPHub -.Shared VPC.- GCPProd
    end

    AWSHub <==>|"IPsec/BGP<br/>4 tunnels"| AzHub
    AWSHub <==>|"IPsec/BGP<br/>4 tunnels"| GCPHub
    AzHub <==>|"IPsec/BGP<br/>4 tunnels"| GCPHub

    Users((External users)) -->|"443"| AWSProd
    Users -->|"443"| AzProd
    Users -->|"443"| GCPProd
```

12 BGP-routed IPsec tunnels total (4 per leg, active-active). Each leg
survives the loss of either endpoint without traffic re-convergence.

---

## 2. Traffic flow — east-west request

User hits the AWS prod ALB; AWS prod EKS pod needs the central audit DB
hosted in GCP.

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant ALB as AWS ALB (public)
    participant Pod as AWS EKS pod<br/>10.20.32.45
    participant TGW as AWS TGW
    participant Tun as IPsec tunnel<br/>(BGP best path)
    participant GHA as GCP HA VPN
    participant Cr as GCP Cloud Router
    participant DB as GCP Cloud SQL<br/>10.80.5.10

    U->>ALB: HTTPS request
    ALB->>Pod: Forwarded to pod via NLB
    Pod->>TGW: Egress to 10.80.5.10
    Note over TGW: TGW RT has propagated route<br/>10.80.0.0/16 → vpn-attach-gcp
    TGW->>Tun: Encapsulated IPsec
    Tun->>GHA: Decapsulated at GCP
    GHA->>Cr: BGP-learned route<br/>10.80.5.10 → spoke subnet
    Cr->>DB: Native VPC routing
    DB-->>Pod: Response (same path, reverse)
```

Failure mode: if one of the 4 tunnels in the leg goes down, BGP withdraws the
route and the remaining 3 carry the load with ~15-30s convergence.

---

## 3. Security zones

```mermaid
flowchart LR
    classDef public fill:#ffcdd2,stroke:#c62828,color:#000
    classDef dmz fill:#fff9c4,stroke:#f57f17,color:#000
    classDef priv fill:#c8e6c9,stroke:#2e7d32,color:#000
    classDef data fill:#bbdefb,stroke:#1565c0,color:#000

    Inet((Internet)):::public
    LB[Public LB / ALB / Front Door]:::dmz
    NSG[Subnet NSG / NACL deny-default]:::dmz
    App[App pods<br/>SG default-deny<br/>egress via TGW]:::priv
    Mesh[Cross-cloud mesh<br/>IPsec only<br/>IKEv2, AES-256-GCM, SHA2-256]:::priv
    Data[Data tier<br/>private subnets<br/>service endpoints / PrivateLink]:::data

    Inet -->|"WAF + TLS"| LB
    LB -->|"explicit allow:80,443"| NSG
    NSG --> App
    App -->|"east-west via mesh"| Mesh
    App -->|"PrivateLink / PSC / Service Endpoint"| Data
```

Enforcement points:
- **Internet → DMZ**: AWS WAF / Azure Front Door / GCP Cloud Armor; TLS terminate.
- **DMZ → app**: SG/NSG default-deny; explicit allow for healthcheck + app ports.
- **App → cross-cloud**: routes ONLY via TGW/VPN. No public egress from app
  subnets (NAT GW is in the public tier; private subnets do not get NAT).
- **App → data**: PaaS reached via PrivateLink (AWS), Private Endpoint (Azure),
  PSC (GCP). No public DB endpoints.

---

## 4. BGP / ASN map

```mermaid
graph LR
    AWS["AWS TGW<br/>ASN 64512"]
    AZ["Azure VPN GW<br/>ASN 65515"]
    GCP["GCP Cloud Router<br/>ASN 65530"]
    MCR["(Megaport MCR)<br/>ASN 64513"]

    AWS -- "advertises 10.10/16, 10.20/16" --> AZ
    AWS -- "advertises 10.10/16, 10.20/16" --> GCP
    AZ -- "advertises 10.40/16, 10.50/16" --> AWS
    AZ -- "advertises 10.40/16, 10.50/16" --> GCP
    GCP -- "advertises 10.70/16, 10.80/16" --> AWS
    GCP -- "advertises 10.70/16, 10.80/16" --> AZ

    MCR -.Option C.- AWS
    MCR -.Option C.- AZ
    MCR -.Option C.- GCP
```

Pod CIDRs (100.64.0.0/10) are **not** advertised across the mesh — pods reach
each other through node-IP NAT, not pod-IP routing.

---

## 5. State + secret topology

```mermaid
flowchart TB
    Dev[Developer]
    GH[GitHub Actions<br/>OIDC]
    SST[S3 + DynamoDB lock<br/>AWS tfstate<br/>KMS-encrypted]
    AZST[Azure Storage<br/>+ blob lease lock]
    GCSST[GCS bucket<br/>+ versioning]
    SecAWS[AWS Secrets Manager<br/>PSKs, OIDC trust]
    KVAz[Azure Key Vault<br/>PSKs, ER service-key]
    SMGCP[GCP Secret Manager<br/>PSKs, pairing keys]

    Dev -->|PR| GH
    GH -- "plan: read-only OIDC role" --> SST
    GH -- "plan: read-only OIDC role" --> AZST
    GH -- "plan: read-only OIDC role" --> GCSST
    GH -. "apply: privileged OIDC role<br/>(manual approval)" .-> SST
    GH -. apply .-> AZST
    GH -. apply .-> GCSST

    SST -.- SecAWS
    AZST -.- KVAz
    GCSST -.- SMGCP
```

PSKs land in Terraform state (random_password). State backends are CMK-encrypted,
versioned, locked, and access-audited. Apply role requires manual approval in
GitHub deployment environments.
