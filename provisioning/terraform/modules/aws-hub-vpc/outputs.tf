output "vpc_id" {
  value       = aws_vpc.this.id
  description = "Hub VPC ID."
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "Hub VPC primary CIDR."
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Public subnet IDs (ALB / NLB)."
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Private app subnet IDs (EKS nodes, app workloads)."
}

output "data_subnet_ids" {
  value       = aws_subnet.data[*].id
  description = "Data subnet IDs (RDS, ElastiCache, MSK)."
}

output "transit_gateway_id" {
  value       = try(aws_ec2_transit_gateway.this[0].id, null)
  description = "TGW ID — null when enable_transit_gateway is false."
}

output "transit_gateway_route_table_id" {
  value       = try(aws_ec2_transit_gateway_route_table.this[0].id, null)
  description = "TGW route-table ID — used by VPN/peering modules to associate cross-cloud attachments."
}

output "flow_log_group_arn" {
  value       = aws_cloudwatch_log_group.flow.arn
  description = "ARN of the CloudWatch log group receiving flow logs."
}

output "vpc_endpoint_security_group_id" {
  value       = aws_security_group.endpoints.id
  description = "SG to attach to any workload that needs to call AWS APIs via interface endpoints."
}
