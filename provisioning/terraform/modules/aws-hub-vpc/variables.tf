variable "name" {
  type        = string
  description = "Logical name prefix (e.g. fastapi-hub). Used in every resource Name tag."
}

variable "cidr_block" {
  type        = string
  description = "Primary VPC CIDR. Must be RFC1918 and non-overlapping with other clouds (see _global/network-cidr-plan.md)."
  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR."
  }
}

variable "azs" {
  type        = list(string)
  description = "Exactly 3 AZs in the region. Three is the minimum for quorum-based services (RDS Multi-AZ, MSK, ElastiCache)."
  validation {
    condition     = length(var.azs) == 3
    error_message = "Provide exactly 3 availability zones."
  }
}

variable "public_subnet_bits" {
  type        = number
  description = "Newbits added to CIDR for public subnets (e.g. 4 on /16 → /20)."
  default     = 4
}

variable "private_subnet_bits" {
  type        = number
  description = "Newbits for private app subnets."
  default     = 4
}

variable "data_subnet_bits" {
  type        = number
  description = "Newbits for data/DB subnets. Smaller block — DBs don't scale wide."
  default     = 6
}

variable "tgw_amazon_side_asn" {
  type        = number
  description = "Amazon-side ASN for Transit Gateway. Must differ from Azure (65515) and GCP (default 64512)."
  default     = 64512
  validation {
    condition     = var.tgw_amazon_side_asn >= 64512 && var.tgw_amazon_side_asn <= 65534
    error_message = "Use a private ASN (64512-65534)."
  }
}

variable "enable_transit_gateway" {
  type        = bool
  description = "Toggle TGW creation. Disable in sandbox to save cost ($0.05/hr/attachment + $0.02/GB)."
  default     = true
}

variable "flow_logs_retention_days" {
  type        = number
  description = "CloudWatch retention for VPC Flow Logs. 90d is the minimum for PCI/SOC2 forensic windows."
  default     = 90
  validation {
    condition     = var.flow_logs_retention_days >= 90
    error_message = "Retention must be >= 90 days for SOC2 / PCI."
  }
}

variable "tags" {
  type        = map(string)
  description = "Standard tag map from modules/common-tags."
}
