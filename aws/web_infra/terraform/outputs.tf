# outputs.tf

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "alb_dns_name" {
  value = module.alb.lb_arn
}

output "ec2_instance_ids" {
  value = module.ec2.instance_ids
}

output "acm_cert_arn" {
  value = module.acm.cert_arn
}
