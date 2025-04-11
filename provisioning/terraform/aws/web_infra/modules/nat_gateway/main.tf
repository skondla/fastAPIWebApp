resource "aws_eip" "nat" {
  tags = { Name = "nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.public_subnet_id
  tags = { Name = "nat-gateway" }
}
