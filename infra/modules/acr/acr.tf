
variable "rg_name" {
  type = string
}
variable "location" {
  type = string
}
variable "name" {
  type = string
}

resource "azurerm_container_registry" "acr" {
  name                = var.name
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "Basic"
  admin_enabled       = true
}
