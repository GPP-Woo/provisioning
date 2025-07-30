# .tfvars file for GPP-WOO development environment
#  (should not live past working days)
project_name = "woo"
environment  = "dev"
location     = "West Europe"
locationcode = "weu"

vm_username = "BastionUser"

resource_tag_values = {
  Provisioner = "Linux/OpenTofu v1.10.3"
  Environment = "dev"
}

ci_vault_name = "kv-devwoo-cisecrets-weu"