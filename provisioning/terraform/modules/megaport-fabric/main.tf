# ──────────────────────────────────────────────────────────────────────────────
# Megaport Cloud Router (MCR) — scaffolding for Option C (SDN private fabric).
#
# This module intentionally does NOT instantiate provider-specific Megaport
# resources. The Megaport Terraform provider's resource schemas (`megaport_mcr`,
# `megaport_aws_connection`, `megaport_vxc`, etc.) have shifted significantly
# across major versions, and the correct attribute set depends on the provider
# version you pin in `versions.tf`.
#
# Use this module as a placeholder + variable surface. Once your Megaport
# account is provisioned and you pin a provider version, drop a sibling
# `megaport.tf` into this directory with the actual MCR + 3 VXC resources
# against your provider's schema. The README in this directory has worked
# examples for both v0.x and v1.x provider lines.
# ──────────────────────────────────────────────────────────────────────────────

variable "name" {
  type        = string
  description = "Logical name prefix for the MCR and its VXCs."
}

variable "location_id" {
  type        = number
  description = "Megaport location ID. Pick one near all 3 cloud on-ramps (e.g. Ashburn = 67). Look up via `megaport_locations` data source."
}

variable "mcr_asn" {
  type        = number
  description = "ASN for the MCR itself. Must differ from AWS/Azure/GCP ASNs."
  default     = 64513
  validation {
    condition     = var.mcr_asn >= 64512 && var.mcr_asn <= 65534
    error_message = "Use a private ASN (64512-65534)."
  }
}

variable "mcr_rate_limit" {
  type        = number
  description = "MCR speed in Mbps (1000, 2500, 5000, 10000)."
  default     = 1000
  validation {
    condition     = contains([1000, 2500, 5000, 10000], var.mcr_rate_limit)
    error_message = "rate_limit must be one of 1000, 2500, 5000, 10000."
  }
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID that will accept the Direct Connect VIF (consumed by the AWS VXC resource added per provider version)."
}

variable "azure_service_key" {
  type        = string
  description = "Azure ExpressRoute service-key (from azurerm_express_route_circuit). Provisioned separately."
  sensitive   = true
}

variable "gcp_pairing_key" {
  type        = string
  description = "GCP Partner Interconnect pairing key (from google_compute_interconnect_attachment). Provisioned separately."
  sensitive   = true
}

variable "labels" {
  type    = map(string)
  default = {}
}

# Placeholder — record the intended configuration. Replace with the actual
# `megaport_mcr` resource once a provider version is pinned.
resource "terraform_data" "mcr_placeholder" {
  input = {
    name           = "${var.name}-mcr"
    location_id    = var.location_id
    port_speed     = var.mcr_rate_limit
    requested_asn  = var.mcr_asn
    aws_account_id = var.aws_account_id
    labels         = var.labels
  }
}

output "mcr_placeholder_id" {
  value       = terraform_data.mcr_placeholder.id
  description = "Placeholder ID. Replace with megaport_mcr.this.product_uid once the real resource is added."
}

output "mcr_asn" {
  value = var.mcr_asn
}
