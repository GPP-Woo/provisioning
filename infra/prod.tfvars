# .tfvars file for GPP-WOO production environment
#  (should persist for "a while")
project_name = "woo"
environment  = "prod"
location     = "West Europe"
locationcode = "weu"

rg_name  = "woo-prod"
acr_name = "wooRegistry"
aks_node_pools = [{
  name       = "default"
  vm_size    = "Standard_D4s_v6"
  node_count = 3
  },
  {
    name       = "user"
    vm_size    = "Standard_D4s_v4" # or, better: Standard_D8s_v6 or Standard_D16s_v6
    node_count = 2
  }
]
# storage_account_name = "woo"

resource_tag_values = {
  Provisioner = "Github/Terraform v1.12.2"
  Environment = "prod"
}

# ci_vault_name = "wooprod-cisecrets"