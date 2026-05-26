terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100, < 4.0"
    }
  }

  # backend "azurerm" {
  #   resource_group_name  = "fastapi-tfstate-rg"
  #   storage_account_name = "fastapitfstate"
  #   container_name       = "tfstate"
  #   key                  = "network/azure/prod.terraform.tfstate"
  # }
}
