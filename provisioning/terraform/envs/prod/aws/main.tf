provider "aws" {
  region = var.region

  default_tags {
    tags = module.tags.tags
  }
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
  source                   = "../../../modules/aws-hub-vpc"
  name                     = "${var.project}-hub"
  cidr_block               = var.hub_cidr
  azs                      = var.azs
  tgw_amazon_side_asn      = var.tgw_asn
  enable_transit_gateway   = true
  flow_logs_retention_days = 365
  tags                     = module.tags.tags
}

module "spoke_prod" {
  source                         = "../../../modules/aws-spoke-vpc"
  name                           = "${var.project}-prod-spoke"
  cidr_block                     = var.prod_spoke_cidr
  azs                            = var.azs
  transit_gateway_id             = module.hub.transit_gateway_id
  transit_gateway_route_table_id = module.hub.transit_gateway_route_table_id
  remote_cidrs                   = concat([var.hub_cidr], var.remote_cidrs)
  flow_logs_retention_days       = 365
  tags                           = module.tags.tags
}
