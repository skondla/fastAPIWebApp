provider "google" {
  project = var.host_project_id
  region  = var.region
}

provider "google-beta" {
  project = var.host_project_id
  region  = var.region
}

module "tags" {
  source              = "../../../modules/common-tags"
  project             = var.project
  environment         = "prod"
  owner               = var.owner
  cost_center         = var.cost_center
  data_classification = "confidential"
  extra               = { layer = "network" }
}

module "hub" {
  source                   = "../../../modules/gcp-hub-vpc"
  name                     = "${var.project}-hub"
  host_project_id          = var.host_project_id
  region                   = var.region
  address_cidr             = var.hub_cidr
  pods_cidr                = var.pods_cidr
  services_cidr            = var.services_cidr
  router_asn               = var.router_asn
  enable_ha_vpn            = true
  flow_logs_retention_days = 365
  labels                   = module.tags.labels
}

module "spoke_prod" {
  source                 = "../../../modules/gcp-spoke-vpc"
  name                   = "${var.project}-prod-spoke"
  host_project_id        = var.host_project_id
  service_project_id     = var.service_project_id
  region                 = var.region
  host_network_self_link = module.hub.network_self_link
  subnet_cidr            = var.spoke_subnet_cidr
  labels                 = module.tags.labels
}
