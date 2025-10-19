terraform {

  required_version = ">= 1.13.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.47.0"
    }
  }

  backend "local" {
    path = "tfstate/terraform.tfstate"
  }

}

provider "azurerm" {
  features {}
  subscription_id                 = "c4faab3e-80a3-4692-aea4-73c5d5e95a99"
  resource_provider_registrations = "none"
}
