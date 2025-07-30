resource "azurerm_virtual_network" "vnet_hub" {
  name                = coalesce(var.hub_name, "vnet-${var.prefix}-hub") # "vnet-hub"
  location            = var.location
  resource_group_name = var.rg_name
  address_space       = [var.hub_address_space]
  tags                = var.tags
}

resource "azurerm_virtual_network" "vnet_aks" {
  name                = coalesce(var.aks_name, "vnet-${var.prefix}-aks") # "vnet-aks"
  location            = var.location
  resource_group_name = var.rg_name
  address_space       = [var.aks_address_space]
  tags                = var.tags
}

resource "azurerm_virtual_network_peering" "to_vnet_aks" {
  name                         = var.aks_vnet_peering
  resource_group_name          = var.rg_name
  virtual_network_name         = azurerm_virtual_network.vnet_hub.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_aks.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
}

resource "azurerm_virtual_network_peering" "to_vnet_hub" {
  name                         = var.hub_vnet_peering
  resource_group_name          = var.rg_name
  virtual_network_name         = azurerm_virtual_network.vnet_aks.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = [var.bastion_subnet]
}

resource "azurerm_subnet" "global" {
  name                              = coalesce(var.global_name, "snet-${var.prefix}-global") # "snet-global"
  resource_group_name               = var.rg_name
  virtual_network_name              = azurerm_virtual_network.vnet_hub.name
  address_prefixes                  = [var.global_subnet]
  private_endpoint_network_policies = "Enabled"
  # private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet" "agw" {
  name                 = coalesce(var.agw_name, "snet-${var.prefix}-agw") # "snet-agw"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.vnet_aks.name
  address_prefixes     = [var.agw_subnet]
}

resource "azurerm_subnet" "aks" {
  name                              = coalesce(var.aks_name, "snet-${var.prefix}-aks") # "snet-aks"
  resource_group_name               = var.rg_name
  virtual_network_name              = azurerm_virtual_network.vnet_aks.name
  address_prefixes                  = [var.aks_subnet]
  private_endpoint_network_policies = "Enabled"
  # private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet" "utils" {
  name                              = coalesce(var.utils_name, "snet-${var.prefix}-utils") # "snet-utils"
  resource_group_name               = var.rg_name
  virtual_network_name              = azurerm_virtual_network.vnet_aks.name
  address_prefixes                  = [var.utils_subnet]
  private_endpoint_network_policies = "Enabled"
  # private_endpoint_network_policies_enabled = true
}
