# Only DEV environment needs this backend.tf. 
# GitHub Actions workflows use OIDC for PROD.
# terraform {
#   backend "azurerm" {
#     # See deploy GHA workflows:
#     #  tf_resource_group_name: "woo-provisioning"
#     #  tf_storage_account_name: "wooprovisioning"
#     #  tf_state_container: "github-oidc-terraform-tfstate"
#     #  tf_state_key: "terraform.tfstate"
#     # resource_group_name  = 
#     # storage_account_name = 
#     # container_name       = 
#     # key                  = 
#     # Consider using this for Azure AD authentication to the backend
#     # use_azuread_auth = true
#   }
# }