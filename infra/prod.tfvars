# .tfvars file for GPP-WOO production environment
#  (should persist for "a while")
project_name = "woo"
environment  = "prod"
location     = "West Europe"
locationcode = "weu"

rg_name  = "woo-aks"
acr_name = "wooRegistry"
aks_name = "woo"
# storage_account_name = "woo"
vm_username = "operator"

resource_tag_values = {
  Provisioner = "Github/Terraform v1.12.2"
  Environment = "prod"
}

ci_vault_name = "woo-cisecrets"