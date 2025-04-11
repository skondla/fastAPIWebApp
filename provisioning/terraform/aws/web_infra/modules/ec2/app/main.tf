resource "aws_instance" "app" {
  count                       = var.app_instance_count
  ami                         = var.ami
  instance_type               = var.instance_type
  # subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  # subnet_id                   = [aws_subnet.private1.id, aws_subnet.private2.id, aws_subnet.private3.id][count.index % 3]
  # subnet_id                   = [var.subnet_ids[count.index % length(var.subnet_ids)]] 
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]  # Select a subnet ID based on the count
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = false
  key_name                    = var.key_name
  user_data                   = file(var.user_data_file)

  tags = {
    Name = "app-${count.index}"
  }
}
