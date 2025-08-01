# .tfvars file for GPP-WOO development environment
#  (should "regularly" and automatically get removed)
project_name = "woo"
environment  = "dev"
location     = "West Europe"
locationcode = "weu"

aks_node_pools = [{
  name       = "default"
  vm_size    = "Standard_DS2_v2"
  node_count = 3
}]

vm_username = "BastionUser"

resource_tag_values = {
  Provisioner = "Linux/OpenTofu v1.10.3"
  Environment = "dev"
}

# ci_vault_name = "woodev-cisecrets"