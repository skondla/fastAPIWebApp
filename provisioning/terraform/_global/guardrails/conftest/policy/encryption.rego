package main

# 1) CloudWatch log groups holding flow logs must be KMS-encrypted.
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_cloudwatch_log_group"
  startswith(resource.change.after.name, "/aws/vpc/")
  not resource.change.after.kms_key_id
  msg := sprintf("aws_cloudwatch_log_group %q stores VPC flow logs but is not KMS-encrypted", [resource.address])
}

# 2) KMS key rotation must be enabled.
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_kms_key"
  resource.change.after.enable_key_rotation != true
  msg := sprintf("aws_kms_key %q does not have key rotation enabled", [resource.address])
}

# 3) Azure Storage used for flow logs must require HTTPS.
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "azurerm_storage_account"
  resource.change.after.enable_https_traffic_only != true
  msg := sprintf("azurerm_storage_account %q allows non-TLS traffic", [resource.address])
}
