
variable "rg_name" {
  type        = string
  description = "The name of the resource group in which to create the storage account."
}
variable "location" {
  type        = string
  description = "The Azure location where the storage account should exist."
}
variable "name" {
  type        = string
  description = "The name of the storage account."
}
variable "tier" {
  type        = string
  default     = "Standard"
  description = "The tier of the storage account."
}
variable "replication_type" {
  type        = string
  default     = "LRS"
  description = "The replication type of the storage account."
}

resource "azurerm_storage_account" "storage" {
  name                     = var.name
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = var.tier
  account_replication_type = var.replication_type
}

output "id" {
  value = azurerm_storage_account.storage.id
}
output "name" {
  value = azurerm_storage_account.storage.name
}