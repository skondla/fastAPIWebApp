resource "aws_instance" "app" {
  count                       = var.instance_count
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = false
  key_name                    = var.key_name
  user_data                   = file(var.user_data_file)

  tags = {
    Name = "app-${count.index}"
  }
}
