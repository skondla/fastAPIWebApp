terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0, < 6.0"
    }
  }

  # backend "gcs" {
  #   bucket = "fastapi-tfstate-prod"
  #   prefix = "network/gcp/prod"
  # }
}
