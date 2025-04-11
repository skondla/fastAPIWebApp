variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "route_table_ids" {
  description = "List of route table IDs to associate with the endpoint"
  type        = list(string)
}

variable "name" {
  description = "Name tag for the S3 gateway endpoint"
  type        = string
}
