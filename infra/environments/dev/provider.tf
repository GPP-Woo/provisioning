# In environments/dev/provider.tf
provider "azurerm" {
  features {}
  # Terraform will automatically use credentials from `az login` when no
  # other explicit credentials (client_id, client_secret, etc.) are provided.
  #  subscription_id = "<Your_Dev_Subscription_ID>"
  #  tenant_id       = "<Your_Dev_Tenant_ID>"
  # Or rather set these environment values for local Terraform/Tofu development:
  #  ARM_SUBSCRIPTION_ID=
}