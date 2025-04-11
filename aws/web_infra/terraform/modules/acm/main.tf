resource "aws_acm_certificate" "imported_cert" {
  private_key       = file(var.key_path)
  certificate_body  = file(var.cert_path)
  certificate_chain = file(var.chain_path)

  tags = {
    Name = var.name
  }
}
