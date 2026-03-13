# Configuration du provider Terraform pour Azure
terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
}

# Provider Azure - l'authentification se fait via az login
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
