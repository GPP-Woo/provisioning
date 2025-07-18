
resource "azurerm_log_analytics_workspace" "law" {
  name                = var.name
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = var.sku
  retention_in_days   = var.retention_in_days
}

resource "azurerm_log_analytics_solution" "law" {
  solution_name         = "Containers"
  workspace_resource_id = azurerm_log_analytics_workspace.law.id
  workspace_name        = azurerm_log_analytics_workspace.law.name
  location              = var.location
  resource_group_name   = var.rg_name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Containers"
  }
}