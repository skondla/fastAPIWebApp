variable "name" {
  type        = string
  description = "Logical spoke name (e.g. fastapi-prod-spoke)."
}

variable "cidr_block" {
  type        = string
  description = "Spoke VPC CIDR. Must not overlap the hub or other spokes."
  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR."
  }
}

variable "azs" {
  type        = list(string)
  description = "Exactly 3 AZs in-region."
  validation {
    condition     = length(var.azs) == 3
    error_message = "Provide exactly 3 availability zones."
  }
}

variable "transit_gateway_id" {
  type        = string
  description = "Hub TGW ID. Spoke attaches and propagates routes here."
}

variable "transit_gateway_route_table_id" {
  type        = string
  description = "Hub TGW route table — spoke association point."
}

variable "remote_cidrs" {
  type        = list(string)
  description = "All remote CIDRs that should be reachable via TGW (other spokes + Azure + GCP). Static routes added to private route tables."
  default     = []
}

variable "flow_logs_retention_days" {
  type        = number
  description = "CloudWatch retention for VPC Flow Logs."
  default     = 90
  validation {
    condition     = var.flow_logs_retention_days >= 90
    error_message = "Retention must be >= 90 days."
  }
}

variable "tags" {
  type        = map(string)
  description = "Standard tag map."
}
