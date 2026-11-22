terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Usa la sesión de "az login" para autenticarse.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
