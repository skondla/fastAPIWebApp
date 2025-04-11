module "vpc" {
  source          = "./modules/vpc"
  cidr_block      = "10.0.0.0/16"
  name            = "main-vpc"
  public_subnets  = { "us-west-2a" = "10.0.1.0/24", "us-west-2b" = "10.0.3.0/24", "us-west-2c" = "10.0.5.0/24" }
  private_subnets = { "us-west-2a" = "10.0.2.0/24", "us-west-2b" = "10.0.4.0/24", "us-west-2c" = "10.0.6.0/24" }
}

module "nat" {
  source            = "./modules/nat_gateway"
  public_subnet_id  = module.vpc.public_subnet_ids[0]
}

module "sg" {
  source  = "./modules/security_groups"
  vpc_id  = module.vpc.vpc_id
}

# module "alb" {
#   source      = "./modules/alb"
#   name        = "app-lb"
#   vpc_id      = module.vpc.vpc_id
#   subnet_ids  = module.vpc.public_subnet_ids
#   sg_id       = module.sg.alb_sg_id
# }

module "alb" {
  source             = "./modules/alb"
  name               = "app-lb"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  sg_id              = module.sg.alb_sg_id
  target_group_port  = 80
  instance_ids     = module.app.instance_ids
}

module "app" {
  source             = "./modules/ec2/app"
  ami                = "ami-087f352c165340ea1"
  instance_type      = "t2.micro"
  key_name           = "ssh-key2-us-west-2"
  subnet_ids         = [module.vpc.private_subnet_ids[0]]
  security_group_ids = [module.sg.alb_sg_id]
  user_data_file     = "bootstrap/bootstrap.sh"
  # count              = var.app_instance_count
  # count              = 3
}

module "bastion" {
  source             = "./modules/ec2/bastion"
  ami                = "ami-087f352c165340ea1"
  instance_type      = "t2.micro"
  key_name           = "ssh-key2-us-west-2"
  subnet_ids         = [module.vpc.public_subnet_ids[0]]
  security_group_ids = [module.sg.bastion_sg_id]
  user_data_file     = "bootstrap/bootstrap.sh"
  # count              = var.bastion_instance_count
  # count              = 1
}



module "acm" {
  source      = "./modules/acm"
  key_path    = "certs/key.pem"
  cert_path   = "certs/certificate.pem"
  chain_path  = "certs/certificate_chain.pem"
  name        = "my-imported-cert"
}
