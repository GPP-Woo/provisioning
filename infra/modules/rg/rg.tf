
variable "name" {
  type        = string
  description = "The name of the resource group."
}
variable "location" {
  type        = string
  description = "The Azure location where the resource group should exist."
}

resource "azurerm_resource_group" "main" {
  name     = var.name
  location = var.location
}

output "id" {
  value = azurerm_resource_group.main.id
}
output "name" {
  value = azurerm_resource_group.main.name
}