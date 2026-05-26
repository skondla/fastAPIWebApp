variable "project" { default = "fastapi" }
variable "megaport_location_id" { type = number }
variable "mcr_asn" {
  type    = number
  default = 64513
}
variable "mcr_rate_limit" {
  type    = number
  default = 1000
}
variable "aws_account_id" { type = string }
variable "azure_service_key" {
  type      = string
  sensitive = true
}
variable "gcp_pairing_key" {
  type      = string
  sensitive = true
}

# Once you've pinned a megaport provider version, uncomment the provider
# block below and add the real megaport_mcr + megaport_vxc resources to a
# sibling .tf file (see modules/megaport-fabric/README.md).
#
# provider "megaport" {
#   # username/password via env: MEGAPORT_USERNAME / MEGAPORT_PASSWORD
#   # for QA: set MEGAPORT_ENVIRONMENT=staging
# }

module "fabric" {
  source = "../../../../modules/megaport-fabric"

  name              = "${var.project}-prod"
  location_id       = var.megaport_location_id
  mcr_asn           = var.mcr_asn
  mcr_rate_limit    = var.mcr_rate_limit
  aws_account_id    = var.aws_account_id
  azure_service_key = var.azure_service_key
  gcp_pairing_key   = var.gcp_pairing_key

  labels = {
    Project     = var.project
    Environment = "prod"
    Topology    = "megaport-sdn"
    CostCenter  = "CC-PLAT-001"
  }
}

output "mcr_placeholder_id" { value = module.fabric.mcr_placeholder_id }
output "mcr_asn" { value = module.fabric.mcr_asn }
