provider "azurerm" {
  # subscription_id = "Please setup .env file or set ARM_SUBSCRIPTION_ID environment value"
  features {}
}

locals {
  prefix = "${var.project_name}${var.environment}"
}

# Create one Resource Group to hold everything
resource "azurerm_resource_group" "rg" {
  name     = coalesce(var.rg_name, "${local.prefix}-rg")
  location = var.location
}

# Create internal, private VNET for cluster, ACR endpoint, etc.
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.prefix}-network"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]
}
resource "azurerm_subnet" "aksinternal" {
  name                 = "${local.prefix}-internal"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = ["10.1.0.0/22"]
}

# Create Azure Container Registry with optional Private Endpoint in private subnet
module "acr" {
  source                    = "./../../modules/acr"
  name                      = coalesce(var.acr_name, "${local.prefix}acrpvaks")
  location                  = azurerm_resource_group.rg.location
  rg_name                   = azurerm_resource_group.rg.name
  sku                       = "Premium"
  admin_enabled             = true
  private_endpoint_enabled  = true
  private_endpoint_subnetid = azurerm_subnet.aksinternal.id
}

# module "law" {
#   source   = "./../../modules/law"
#   name     = "${local.prefix}-law"
#   location = azurerm_resource_group.rg.location
#   rg_name  = azurerm_resource_group.rg.name
# }
# module "aks" {
#   source             = "./../../modules/aks"
#   name               = coalesce(var.aks_name, "${local.prefix}-aks")
#   location           = azurerm_resource_group.rg.location
#   rg_name            = azurerm_resource_group.rg.name
#   vnet_subnet_id     = azurerm_subnet.aksinternal.id
#   law_id             = module.law.id
#   kubernetes_version = "1.33.0"
#   node_pools = [
#     {
#       name       = "default"
#       vm_size    = "Standard_DS2_v2"
#       node_count = 2
#     },
#     {
#       name       = "user"
#       vm_size    = "Standard_DS2_v2"
#       node_count = 2
#     }
#   ]
# }



# module "storage" {
#   source   = "./../../modules/storage"
#   name     = "${local.prefix}-sa"
#   location = azurerm_resource_group.rg.location
#   rg_name  = azurerm_resource_group.rg.name
# }

# module "cloudnativepg" {
#   source            = "./../../modules/cloudnativepg"
#   rg_name           = azurerm_resource_group.rg.name
#   location          = azurerm_resource_group.rg.location
#   postgres_pv_name  = "${local.prefix}-cnpg-pv"
#   postgres_pvc_name = "${local.prefix}-cnpg-pvc"
# }


