output "vpc_id" {
  value       = aws_vpc.this.id
  description = "Spoke VPC ID."
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "Spoke VPC primary CIDR."
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Spoke private subnet IDs (workload placement)."
}

output "tgw_attachment_id" {
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
  description = "TGW attachment ID — surface for cross-cloud route propagation."
}
