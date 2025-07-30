
variable "rg_name" {
  type        = string
  description = "The name of the resource group in which to create the container registry."
}
variable "location" {
  type        = string
  description = "The Azure location where the container registry should exist."
}
variable "prefix" {
  type        = string
  description = "String to insert in resources, e.g. <resource>-<prefix>-<use>"
}
variable "name" {
  type        = string
  description = "The name of the container registry."
}
variable "sku" {
  type        = string
  default     = "Basic"
  description = "The SKU of the container registry."
}
variable "admin_enabled" {
  type        = bool
  default     = false
  description = "Should the admin user be enabled?"
}
variable "private_endpoint_enabled" {
  type        = bool
  default     = false
  description = "Should a private_endpoint be created?"
}
variable "private_endpoint_subnetid" {
  type        = string
  default     = null
  description = "Setup private endpoint in this subnet ID (optional)"
}
variable "public_network_access_enabled" {
  type        = bool
  default     = false
  description = "Whether or not to allow public network access"
}
variable "aks_vnet_id" {
  type        = string
  description = "The AKS vnet_id"
}
variable "hub_vnet_id" {
  type        = string
  description = "The HUB vnet_id"
}
variable "tags" {
  description = "Resource Tag Values"
  type        = map(string)
  # default     = {
  #   "<existingOrnew-tag-name1>" = "<existingOrnew-tag-value1>"
  #   "<existingOrnew-tag-name2>" = "<existingOrnew-tag-value2>"
  #   "<existingOrnew-tag-name3>" = "<existingOrnew-tag-value3>"
  # }
}

resource "azurerm_container_registry" "acr" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.rg_name
  sku                           = var.sku
  admin_enabled                 = var.admin_enabled
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}


resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.rg_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr1" {
  name                  = "pdznl-${var.prefix}acr-001" # "pdznl-acr-weu-001"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = var.hub_vnet_id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr2" {
  name                  = "pdznl-${var.prefix}acr-002" # "pdznl-acr-weu-002"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = var.aks_vnet_id
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "acr" {
  count               = var.private_endpoint_enabled ? 1 : 0
  name                = "pe-${var.prefix}acr-001" # "pe-acr-weu-001"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.private_endpoint_subnetid
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.prefix}acr-001"
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "pdzg-${var.prefix}acr-001" # "pdzg-acr-cac-001"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }
}


output "id" {
  value = azurerm_container_registry.acr.id
}
output "name" {
  value = azurerm_container_registry.acr.name
}