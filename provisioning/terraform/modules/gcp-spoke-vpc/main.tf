terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 6.0"
    }
  }
}

variable "name" { type = string }
variable "host_project_id" {
  type        = string
  description = "Shared VPC host project."
}
variable "service_project_id" {
  type        = string
  description = "Spoke service project — will be attached to the host."
}
variable "region" { type = string }
variable "host_network_self_link" {
  type        = string
  description = "Hub VPC self link."
}
variable "subnet_cidr" { type = string }
variable "pods_cidr" {
  type    = string
  default = null
}
variable "services_cidr" {
  type    = string
  default = null
}
variable "labels" { type = map(string) }

resource "google_compute_shared_vpc_service_project" "this" {
  host_project    = var.host_project_id
  service_project = var.service_project_id
}

resource "google_compute_subnetwork" "spoke" {
  name          = "${var.name}-subnet"
  project       = var.host_project_id
  region        = var.region
  network       = var.host_network_self_link
  ip_cidr_range = var.subnet_cidr

  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = var.pods_cidr == null ? [] : [1]
    content {
      range_name    = "pods"
      ip_cidr_range = var.pods_cidr
    }
  }

  dynamic "secondary_ip_range" {
    for_each = var.services_cidr == null ? [] : [1]
    content {
      range_name    = "services"
      ip_cidr_range = var.services_cidr
    }
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

output "subnet_id" { value = google_compute_subnetwork.spoke.id }
output "subnet_self_link" { value = google_compute_subnetwork.spoke.self_link }
