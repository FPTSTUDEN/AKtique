terraform {
  required_version = ">=1.3"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~>2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~>0.13"
    }
  }
}

provider "azurerm" {
  features {}
}