terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote State (empfohlen, siehe backend.tf.example). Standardmässig lokaler State,
  # damit der Nachbau ohne Vorbereitung möglich ist. Die Datei terraform.tfstate darf
  # NIEMALS in das öffentliche Repository gelangen (enthält das SQL-Passwort).
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  # subscription_id wird über ARM_SUBSCRIPTION_ID oder az login übernommen.
}
