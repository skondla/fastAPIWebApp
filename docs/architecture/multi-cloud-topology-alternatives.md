# Alternative multi-cloud topologies

Diagrams for the three alternative options in
`provisioning/terraform/envs/prod/cross-cloud-alternatives/`.

---

## Option A (default) — Full-mesh IPsec

Already documented in [multi-cloud-network.md](./multi-cloud-network.md).

---

## Option B — AWS TGW hub-and-spoke

```mermaid
flowchart LR
    subgraph AWS["AWS — us-east-1"]
        TGW["Transit Gateway<br/>(hub)"]
    end
    subgraph Azure["Azure — eastus2"]
        AZGW["VPN Gateway"]
    end
    subgraph GCP["GCP — us-east4"]
        GCPGW["HA VPN Gateway"]
    end

    AZGW <-.IPsec/BGP.-> TGW
    GCPGW <-.IPsec/BGP.-> TGW
    AZGW -. "Azure↔GCP traffic transits AWS" .-> GCPGW
```

8 tunnels total (4 per leg). No direct Azure↔GCP path.

---

## Option C — Megaport Cloud Router (SDN)

```mermaid
flowchart LR
    MCR["Megaport Cloud Router<br/>ASN 64513"]
    AWS["AWS Direct Connect<br/>(DXGW)"]
    Az["Azure ExpressRoute<br/>(ER Circuit)"]
    GCP["GCP Partner Interconnect"]

    MCR <==> AWS
    MCR <==> Az
    MCR <==> GCP

    AWS --- TGW["AWS TGW"]
    Az --- AzVWAN["Azure VWAN / VNet GW"]
    GCP --- GCPVPC["GCP VPC"]
```

3 VXCs, no IPsec, 5-15ms cross-cloud latency, up to 10 Gbps per VXC.

---

## Option D — Azure Virtual WAN hub

```mermaid
flowchart LR
    subgraph Azure["Azure Virtual WAN — eastus2"]
        VHUB["Virtual Hub<br/>+ S2S VPN GW<br/>+ Azure Firewall Premium"]
        Spokes["Azure VNet spokes"]
        VHUB <-.VHC peering.-> Spokes
    end

    subgraph AWS["AWS — us-east-1"]
        ATGW["TGW"]
    end
    subgraph GCP["GCP — us-east4"]
        GHVPN["HA VPN"]
    end

    VHUB <-.VPN site.-> ATGW
    VHUB <-.VPN site.-> GHVPN
```

Azure manages all branch-to-branch routing; in-hub firewall inspects every
packet without UDR plumbing.

---

## Picking between options

| If your priority is …            | Pick                                    |
|----------------------------------|-----------------------------------------|
| No vendor lock-in                | A (default mesh)                        |
| Lowest cost                      | B (AWS hub) — at the cost of HA         |
| Lowest latency / highest BW      | C (Megaport)                            |
| Managed routing service          | D (Azure VWAN) if Azure-centric         |
| HA across cloud-region failures  | A or C                                  |
