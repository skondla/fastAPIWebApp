output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3_gateway.id
}
output "s3_endpoint_arn" {
  value = aws_vpc_endpoint.s3_gateway.arn
}


output "public_route_table_id" {
  value = aws_route_table.public_rt.id
}

output "private_route_table_id" {
  value = aws_default_route_table.private_route_table.id
}