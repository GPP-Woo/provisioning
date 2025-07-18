# # In environments/dev/backend.tf and environments/prod/backend.tf
# terraform {
#   backend "azurerm" {
#     # from deploy GHA workflow:
#     #  tf_resource_group_name: "woo-provisioning"
#     #  tf_storage_account_name: "wooprovisioning"
#     #  tf_state_container: "github-oidc-terraform-tfstate"
#     #  tf_state_key: "terraform.tfstate"

#     # Consider using this for Azure AD authentication to the backend
#     # use_azuread_auth = true
#   }
# }