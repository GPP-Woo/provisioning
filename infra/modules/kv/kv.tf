data "azurerm_client_config" "current" {}

variable "rg_name" {
  type        = string
  description = "The name of the resource group in which to create the Key Vault."
}
variable "location" {
  type        = string
  description = "The Azure location where the Key Vault should live."
}
variable "locationcode" {
  type        = string
  description = "The Azure region code for tagging the Key Vault name (unless specified)."
}
variable "prefix" {
  type        = string
  description = "String to insert in resources, e.g. <resource>-<prefix>-<use>"
}
variable "name" {
  type        = string
  description = "The name of the Key Vault."
  default     = null
}
variable "sku" {
  type        = string
  description = "Azure Key Vault type (SKU)"
  default     = "standard"
}
variable "pod_principal_id" {
  type        = string
  description = "The k8s pod principal_id granted access to the vault"
}
variable "vnet_hub_id" {
  type        = string
  description = "The HUB vnet_id to connect nodes to"
}
variable "vnet_aks_id" {
  type        = string
  description = "The AKS vnet_id to connect nodes to"
}
variable "snet_utils_id" {
  type        = string
  description = "Utils subnet_id to expose the Key Vault"
}
resource "azurerm_key_vault" "kv" {
  name                = coalesce(var.name, "kv-${var.prefix}-${var.locationcode}")
  location            = var.location
  resource_group_name = var.rg_name
  tenant_id           = data.azurerm_client_config.current.tenant_id

  sku_name = var.sku

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = var.pod_principal_id

    secret_permissions = [
      "Get", "List",
    ]
  }
}

resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.rg_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv1" {
  name                  = "pdznl-${var.prefix}kv-aks" # "pdznl-vault-cac-001"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = var.vnet_aks_id
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv2" {
  name                  = "pdznl-${var.prefix}kv-hub" # "pdznl-vault-cac-002"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = var.vnet_hub_id
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-${var.prefix}kv-001" # "pe-vault-cac-001"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.snet_utils_id

  private_service_connection {
    name                           = "psc-${var.prefix}kv-001" # "psc-vault-cac-001"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-${var.prefix}kv-001" # "pdzg-vault-cac-001"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
}