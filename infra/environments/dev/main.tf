provider "azurerm" {
  # Please setup OIDC or ARM_SUBSCRIPTION_ID environment value
  features {}
  # Terraform/OpenTofu reuse `az login` session when no explicit
  # credentials (client_id, client_secret, etc.) are provided.
  #  subscription_id = "<Your_Dev_Subscription_ID>"
  #  tenant_id       = "<Your_Dev_Tenant_ID>"
}

locals {
  prefix = "${var.project_name}${var.environment}"
}

# Create one Resource Group to hold everything
resource "azurerm_resource_group" "rg" {
  name     = coalesce(var.rg_name, "rg-${local.prefix}-${var.locationcode}")
  location = var.location
}

# Create internal, private VNET for cluster, ACR endpoint, etc.
module "vnets" {
  source            = "./../../modules/vnets"
  prefix            = local.prefix
  hub_name          = "vnet-${local.prefix}-hub"
  aks_name          = "vnet-${local.prefix}-aks"
  location          = azurerm_resource_group.rg.location
  rg_name           = azurerm_resource_group.rg.name
  tags              = var.resource_tag_values
  hub_address_space = "10.0.0.0/16"
  bastion_subnet    = "10.0.0.0/27"
  global_subnet     = "10.0.1.0/24"
  aks_address_space = "10.1.0.0/16"
  agw_subnet        = "10.1.0.0/24"
  utils_subnet      = "10.1.2.0/24"
  aks_subnet        = "10.1.4.0/22"
}

# Create Azure Container Registry with optional Private Endpoint in private subnet
module "acr" {
  source                        = "./../../modules/acr"
  prefix                        = local.prefix
  name                          = coalesce(var.acr_name, "${local.prefix}pvaks${var.locationcode}")
  location                      = azurerm_resource_group.rg.location
  rg_name                       = azurerm_resource_group.rg.name
  tags                          = var.resource_tag_values
  sku                           = "Premium"
  admin_enabled                 = true
  private_endpoint_enabled      = true
  private_endpoint_subnetid     = module.vnets.snet_global_id
  aks_vnet_id                   = module.vnets.vnet_aks_id
  hub_vnet_id                   = module.vnets.vnet_hub_id
  public_network_access_enabled = false
}

# Create Application Gateway, managed by AKS with AGIC addon. It will have a private
# IP address set by us, and a public IP address assigned from Microsoft Azure.
module "agw" {
  source             = "./../../modules/agw"
  prefix             = local.prefix
  name               = coalesce(var.acr_name, "agw-${local.prefix}-pvaks-${var.locationcode}")
  location           = azurerm_resource_group.rg.location
  rg_name            = azurerm_resource_group.rg.name
  tags               = var.resource_tag_values
  subnet_id          = module.vnets.snet_agw_id
  private_ip_address = "10.1.0.4"
}

# Provision a Log Analytics Workspace:
module "law" {
  source   = "./../../modules/law"
  name     = coalesce(var.law_name, "law-${local.prefix}-pvaks-${var.locationcode}")
  location = azurerm_resource_group.rg.location
  rg_name  = azurerm_resource_group.rg.name
  tags     = var.resource_tag_values
}

# Setup our private AKS cluster:
module "aks" {
  source             = "./../../modules/aks"
  prefix             = local.prefix
  name               = coalesce(var.aks_name, "aks-${local.prefix}-${var.locationcode}")
  location           = azurerm_resource_group.rg.location
  rg_name            = azurerm_resource_group.rg.name
  aks_subnet_id      = module.vnets.snet_aks_id
  vnet_aks_id        = module.vnets.vnet_aks_id
  vnet_hub_id        = module.vnets.vnet_hub_id
  service_cidr       = "10.1.3.0/24"
  dns_service_ip     = "10.1.3.4"
  law_id             = module.law.id
  agw_id             = module.agw.id
  acr_id             = module.acr.id
  rg_id              = azurerm_resource_group.rg.id
  kubernetes_version = var.kubernetes_version
  node_pools = [
    {
      name       = "default"
      vm_size    = "Standard_DS2_v2"
      node_count = 3
    },
    # {
    #   name       = "user"
    #   vm_size    = "Standard_DS2_v2"
    #   node_count = 2
    # }
  ]
}

# Provision a MS Container Insights into Analytics Workspace:
module "msci" {
  source       = "./../../modules/msci"
  name         = "mcsi-${local.prefix}-pvaks-${var.locationcode}"
  prefix       = local.prefix
  location     = azurerm_resource_group.rg.location
  rg_name      = azurerm_resource_group.rg.name
  tags         = var.resource_tag_values
  cluster_id   = module.aks.id
  cluster_name = module.aks.name
  law_id       = module.law.id
}


# Add a Key Vault, accessible for pods:
module "kv" {
  source           = "./../../modules/kv"
  name             = "kv-${local.prefix}-pvaks-${var.locationcode}"
  location         = azurerm_resource_group.rg.location
  locationcode     = var.locationcode
  rg_name          = azurerm_resource_group.rg.name
  tags             = var.resource_tag_values
  prefix           = local.prefix
  pod_principal_id = module.aks.pod_principal_id
  vnet_aks_id      = module.vnets.vnet_aks_id
  vnet_hub_id      = module.vnets.vnet_hub_id
  snet_utils_id    = module.vnets.snet_utils_id
}

# Add a Bastion and optional VM:
module "bastion" {
  source          = "./../../modules/bastion"
  name            = "bastion-${local.prefix}-${var.locationcode}"
  location        = azurerm_resource_group.rg.location
  rg_name         = azurerm_resource_group.rg.name
  tags            = var.resource_tag_values
  prefix          = local.prefix
  snet_global_id  = module.vnets.snet_global_id
  snet_bastion_id = module.vnets.snet_bastion_id
  vm_username     = "BastionUser"
  k8s_io_version  = join("", regex("^(\\d+\\.\\d+)(?:\\.\\d+)", var.kubernetes_version))
  kube_config     = module.aks.kube_config
  # locationcode    = var.locationcode
}

# module "storage" {
#   source   = "./modules/storage"
#   name     = "${local.prefix}-sa"
#   location = azurerm_resource_group.rg.location
#   rg_name  = azurerm_resource_group.rg.name
# }

# module "cloudnativepg" {
#   source            = "./modules/cloudnativepg"
#   rg_name           = azurerm_resource_group.rg.name
#   location          = azurerm_resource_group.rg.location
#   postgres_pv_name  = "${local.prefix}-cnpg-pv"
#   postgres_pvc_name = "${local.prefix}-cnpg-pvc"
# }


output "aks" {
  value     = module.aks
  sensitive = true
}
output "aks_kubeconfig" {
  value     = module.aks.kube_config
  sensitive = true
}
output "bastion_name" {
  value = module.bastion.bastion_name
}
output "vm_password" {
  value     = module.bastion.vm_password
  sensitive = true
}
output "vm_privkey" {
  value     = module.bastion.vm_privatekey
  sensitive = true
}
output "vm1_ip" {
  value = module.bastion.vm1_ip
}
output "vm1_access_howto" {
  value     = module.bastion.vm1_access_howto
  sensitive = true
}
output "vm2_ip" {
  value = module.bastion.vm2_ip
}