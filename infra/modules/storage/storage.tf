
variable "rg_name" {
  type = string
}
variable "location" {
  type = string
}
variable "name" {
  type = string
}

resource "azurerm_storage_account" "storage" {
  name                     = var.name
  resource_group_name      = var.rg_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
