resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = var.name }
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value
  map_public_ip_on_launch = true
  availability_zone       = each.key
  tags = { Name = "public-${each.key}" }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets
  vpc_id     = aws_vpc.main.id
  cidr_block = each.value
  availability_zone       = each.key
  tags = { Name = "private-${each.key}" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "main-igw" }
}
