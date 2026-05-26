provider "azurerm" {
  features {}
}

module "tags" {
  source              = "../../../modules/common-tags"
  project             = var.project
  environment         = "prod"
  owner               = var.owner
  cost_center         = var.cost_center
  data_classification = "confidential"
  extra               = { Layer = "network" }
}

module "hub" {
  source                       = "../../../modules/azure-hub-vnet"
  name                         = "${var.project}-hub"
  location                     = var.location
  resource_group_name          = "${var.project}-hub-rg"
  address_space                = var.hub_address_space
  enable_firewall              = true
  enable_vpn_gateway           = true
  vpn_gateway_asn              = var.vpn_gateway_asn
  flow_logs_retention_days     = 365
  log_analytics_workspace_id   = var.log_analytics_workspace_id
  flow_logs_storage_account_id = var.flow_logs_storage_account_id
  tags                         = module.tags.tags
}

module "spoke_prod" {
  source                  = "../../../modules/azure-spoke-vnet"
  name                    = "${var.project}-prod-spoke"
  location                = var.location
  resource_group_name     = "${var.project}-prod-rg"
  address_space           = var.prod_spoke_address_space
  hub_vnet_id             = module.hub.vnet_id
  hub_vnet_name           = module.hub.vnet_name
  hub_resource_group_name = module.hub.resource_group_name
  firewall_private_ip     = module.hub.firewall_private_ip
  tags                    = module.tags.tags
}
