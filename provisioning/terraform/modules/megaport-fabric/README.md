# Module: megaport-fabric (scaffolding)

Models Megaport Cloud Router (MCR) plus three Virtual Cross-Connects (VXCs) —
one to AWS (Direct Connect Hosted Connection), one to Azure (ExpressRoute
Hosted Service Key), one to GCP (Partner Interconnect pairing key).

## Prereqs (NOT created by this module)
- Megaport account + API credentials (`MEGAPORT_USERNAME` / `_PASSWORD`).
- AWS Direct Connect Gateway and accepted VIF (or the partner port UID).
- Azure ExpressRoute circuit (Standard SKU minimum, Premium for global reach)
  in `Enabled` provisioning state. Service key surfaces from the circuit.
- GCP `google_compute_interconnect_attachment` in `PENDING_PARTNER` state.
  Pairing key surfaces from the attachment.

The reason these aren't in this module: each one is a stateful object that
takes 10-30 minutes to provision and is paid by the hour. Letting this module
manage them risks accidental teardown on a destructive plan.

## Why MCR not physical Port
MCR is a virtual layer-3 router managed by Megaport. You get BGP + VLAN + VXCs
without owning hardware. Physical Port + Direct Connect requires LOAs, cross-
connects, and Mb-per-month port commit — out of scope for an IaC scaffold.

## Costs (rough, USD)
- MCR 1 Gbps month-to-month: ~$700/mo
- Each VXC: ~$200-400/mo depending on bandwidth + location pair
- Annual / 36-month commit reduces 20-40%
- Replaces ~$500-800/mo of native VPN data-transfer fees at high volume

## Activation
Not deployable without real credentials and accepted provisioning emails on
the Megaport portal. Use this as a starting point; expect ~3-5 days of back-
and-forth with Megaport support for first-time setup.
