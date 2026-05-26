variable "name" {
  type        = string
  description = "Logical name prefix (e.g. fastapi-hub)."
}

variable "host_project_id" {
  type        = string
  description = "Project that owns the Shared VPC. Must already exist; this module flips it into host mode."
}

variable "region" {
  type        = string
  description = "Primary region (e.g. us-east4)."
}

variable "address_cidr" {
  type        = string
  description = "Hub VPC primary CIDR. Must not overlap AWS/Azure."
  validation {
    condition     = can(cidrhost(var.address_cidr, 0))
    error_message = "address_cidr must be a valid CIDR."
  }
}

variable "pods_cidr" {
  type        = string
  description = "Secondary range for GKE pods (RFC 6598 100.64.0.0/10 recommended to save RFC1918 space)."
  default     = "100.64.0.0/14"
}

variable "services_cidr" {
  type        = string
  description = "Secondary range for GKE services."
  default     = "100.72.0.0/16"
}

variable "router_asn" {
  type        = number
  description = "BGP ASN for the Cloud Router that fronts HA VPN. Must differ from AWS/Azure."
  default     = 65530
  validation {
    condition     = var.router_asn >= 64512 && var.router_asn <= 65534
    error_message = "Use a private ASN (64512-65534)."
  }
}

variable "enable_ha_vpn" {
  type        = bool
  description = "Toggle HA VPN gateway (needed for cross-cloud IPsec)."
  default     = true
}

variable "flow_logs_retention_days" {
  type        = number
  description = "Pub/Sub or Logging sink retention surfaced for downstream consumers — VPC flow log enablement is per-subnet below."
  default     = 90
  validation {
    condition     = var.flow_logs_retention_days >= 90
    error_message = "Retention must be >= 90 days."
  }
}

variable "labels" {
  type        = map(string)
  description = "Standard label map (GCP-safe — lowercase)."
}
