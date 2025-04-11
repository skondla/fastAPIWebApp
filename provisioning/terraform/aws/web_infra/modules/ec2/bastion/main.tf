resource "aws_instance" "bastion" {
  count                       = var.bastion_instance_count
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  # subnet_id                   = [aws_subnet.public1.id, aws_subnet.public2.id, aws_subnet.public3.id][0]
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data                   = file(var.user_data_file)

  tags = {
    Name = "bastion-${count.index}"
  }
}
