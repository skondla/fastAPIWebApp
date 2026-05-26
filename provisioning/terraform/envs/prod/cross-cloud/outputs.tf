output "aws_azure_aws_vpn_connection_ids" {
  value = module.aws_azure.aws_vpn_connection_ids
}

output "aws_azure_azure_connection_ids" {
  value = module.aws_azure.azure_connection_ids
}

output "aws_gcp_aws_vpn_connection_ids" {
  value = module.aws_gcp.aws_vpn_connection_ids
}

output "aws_gcp_gcp_vpn_tunnel_ids" {
  value = module.aws_gcp.gcp_vpn_tunnel_ids
}

output "azure_gcp_azure_connection_ids" {
  value = module.azure_gcp.azure_connection_ids
}

output "azure_gcp_gcp_vpn_tunnel_ids" {
  value = module.azure_gcp.gcp_vpn_tunnel_ids
}
