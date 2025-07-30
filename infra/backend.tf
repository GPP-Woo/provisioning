# Only DEV environment needs this backend.tf. 
# GitHub Actions workflows use OIDC for PROD.
terraform {
  backend "azurerm" {
    # resource_group_name  = "woo-provisioning"
    # storage_account_name = "wooprovisioning"
    # container_name       = "manual-terraform-tfstate"
    # key                  = "aks-wooprovisioning-dev.tfstate" # Unique key per environment

    resource_group_name  = ""
    storage_account_name = ""
    container_name       = ""
    key                  = ""

    # Consider using this for Azure AD authentication to the backend
    # use_azuread_auth = true
  }
}