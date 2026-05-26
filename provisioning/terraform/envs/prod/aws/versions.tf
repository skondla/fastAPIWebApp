terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40, < 6.0"
    }
  }

  # Remote backend (uncomment + parameterise per environment).
  # Production state must live in an encrypted, versioned, locked backend.
  # backend "s3" {
  #   bucket         = "fastapi-tfstate-prod"
  #   key            = "network/aws/prod.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   kms_key_id     = "alias/tfstate"
  #   dynamodb_table = "fastapi-tfstate-locks"
  # }
}
