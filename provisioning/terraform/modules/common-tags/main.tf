terraform {
  required_version = ">= 1.5.0"
}

variable "project" {
  type        = string
  description = "Project name. Used as a tag key on every resource so cost reports and IR queries can filter by it."
}

variable "environment" {
  type        = string
  description = "Deployment environment (prod, nonprod, sandbox)."
  validation {
    condition     = contains(["prod", "nonprod", "sandbox"], var.environment)
    error_message = "environment must be one of: prod, nonprod, sandbox."
  }
}

variable "owner" {
  type        = string
  description = "Team or business owner. Required for charge-back and IR ownership."
}

variable "cost_center" {
  type        = string
  description = "Cost-center / GL code. Surfaces in CUR and matches finance ledger."
}

variable "data_classification" {
  type        = string
  description = "Highest data class processed by this resource."
  default     = "internal"
  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be one of: public, internal, confidential, restricted."
  }
}

variable "extra" {
  type        = map(string)
  description = "Caller-supplied tags merged last. Use for resource-specific labels."
  default     = {}
}

locals {
  base = {
    Project            = var.project
    Environment        = var.environment
    Owner              = var.owner
    CostCenter         = var.cost_center
    DataClassification = var.data_classification
    ManagedBy          = "terraform"
    Repo               = "fastAPIWebApp"
  }
  tags = merge(local.base, var.extra)
}

output "tags" {
  value       = local.tags
  description = "Standard tag map for AWS/Azure providers."
}

output "labels" {
  description = "Lowercase, GCP-safe label map (GCP labels reject uppercase and certain chars)."
  value = {
    for k, v in local.tags :
    lower(replace(k, "/[^a-z0-9_-]/", "_")) => lower(replace(v, "/[^a-z0-9_-]/", "_"))
  }
}
