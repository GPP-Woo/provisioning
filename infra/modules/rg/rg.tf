
variable "name" {
  type        = string
  description = "The name of the resource group."
}
variable "location" {
  type        = string
  description = "The Azure location where the resource group should exist."
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

resource "azurerm_resource_group" "main" {
  name     = var.name
  location = var.location
  tags     = var.tags
}

output "id" {
  value = azurerm_resource_group.main.id
}
output "name" {
  value = azurerm_resource_group.main.name
}