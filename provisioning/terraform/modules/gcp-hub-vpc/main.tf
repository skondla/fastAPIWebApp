resource "google_compute_network" "this" {
  name                            = "${var.name}-vpc"
  project                         = var.host_project_id
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = false
}

# Mark as Shared VPC host so spoke (service) projects can attach.
resource "google_compute_shared_vpc_host_project" "this" {
  project = var.host_project_id
}

resource "google_compute_subnetwork" "primary" {
  name          = "${var.name}-primary"
  project       = var.host_project_id
  region        = var.region
  network       = google_compute_network.this.id
  ip_cidr_range = cidrsubnet(var.address_cidr, 4, 0)

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud Router + NAT (workloads stay private; egress NAT for updates).
resource "google_compute_router" "this" {
  name    = "${var.name}-router"
  project = var.host_project_id
  region  = var.region
  network = google_compute_network.this.id

  bgp {
    asn               = var.router_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_router_nat" "this" {
  name                                = "${var.name}-nat"
  project                             = var.host_project_id
  router                              = google_compute_router.this.name
  region                              = var.region
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  enable_endpoint_independent_mapping = false

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ─── Firewall baseline ────────────────────────────────────────────────────────
# 1) Explicit deny-all ingress at low priority — overrides GCP's implicit allow-from-internet (there isn't one, but we make intent explicit).
resource "google_compute_firewall" "deny_all_ingress" {
  name      = "${var.name}-deny-all-ingress"
  project   = var.host_project_id
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

# 2) Allow east-west within hub + spokes + cross-cloud CIDRs (caller-controlled).
resource "google_compute_firewall" "allow_internal" {
  name      = "${var.name}-allow-internal"
  project   = var.host_project_id
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [var.address_cidr, var.pods_cidr, var.services_cidr]
}

# 3) IAP TCP-forwarding for SSH bastion-less access.
resource "google_compute_firewall" "allow_iap_ssh" {
  name      = "${var.name}-allow-iap-ssh"
  project   = var.host_project_id
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # IAP CIDR
  target_tags   = ["iap-ssh"]
}

# 4) GKE master access (for private clusters).
resource "google_compute_firewall" "allow_gke_master" {
  name      = "${var.name}-allow-gke-master-webhook"
  project   = var.host_project_id
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["443", "10250", "8443", "9443", "15017"]
  }

  source_ranges = [var.address_cidr]
  target_tags   = ["gke-node"]
}

# ─── HA VPN gateway (two public interfaces, two tunnels per peer) ─────────────
resource "google_compute_ha_vpn_gateway" "this" {
  count   = var.enable_ha_vpn ? 1 : 0
  name    = "${var.name}-ha-vpn"
  project = var.host_project_id
  region  = var.region
  network = google_compute_network.this.id
}

# ─── Private Service Connect endpoint for Google APIs ────────────────────────
# Workloads call *.p.googleapis.com via this private endpoint — no public egress.
resource "google_compute_global_address" "psc_apis" {
  name          = "${var.name}-psc-apis-ip"
  project       = var.host_project_id
  address_type  = "INTERNAL"
  purpose       = "PRIVATE_SERVICE_CONNECT"
  network       = google_compute_network.this.id
  address       = cidrhost(cidrsubnet(var.address_cidr, 8, 255), 0)
  prefix_length = 24
}

resource "google_compute_global_forwarding_rule" "psc_apis" {
  name                  = "${var.name}-psc-apis"
  project               = var.host_project_id
  target                = "all-apis"
  network               = google_compute_network.this.id
  ip_address            = google_compute_global_address.psc_apis.id
  load_balancing_scheme = ""
}
