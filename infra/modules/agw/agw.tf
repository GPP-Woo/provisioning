
variable "rg_name" {
  type        = string
  description = "The name of the resource group in which to create the application gateway."
}
variable "location" {
  type        = string
  description = "The Azure location where the container appgw should exist."
}
variable "prefix" {
  type        = string
  description = "String to insert in resources, e.g. <resource>-<prefix>-<use>"
}
variable "name" {
  type        = string
  description = "The name of the Application Gateway."
}
variable "subnet_id" {
  type        = string
  description = "The subnet_id to link the appgw into."
}
variable "private_ip_address" {
  type        = string
  description = "The private IP address for the internal appgw connection"
}

locals {
  backend_address_pool_name              = "bapn-pvaks"
  frontend_port_name                     = "fpn-pvaks"
  private_frontend_ip_configuration_name = "ficn-pvaks-private"
  public_frontend_ip_configuration_name  = "ficn-pvaks-public"
  http_setting_name                      = "hsn-pvaks"
  private_listener_name                  = "ln-pvaks-http-private"
  public_listener_name                   = "ln-pvaks-http-public"
  request_routing_rule_name              = "rrrn-pvaks"
  redirect_configuration_name            = "rrn-pvaks"
}

resource "azurerm_public_ip" "ip" {
  name                = "pip-pvaks"
  resource_group_name = var.rg_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "agw" {
  name                = "agw-pvaks"
  resource_group_name = var.rg_name
  location            = var.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "ipc-pvaks"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.public_frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.ip.id
  }

  frontend_ip_configuration {
    name                          = local.private_frontend_ip_configuration_name
    private_ip_address            = var.private_ip_address
    private_ip_address_allocation = "Static"
    subnet_id                     = var.subnet_id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.public_listener_name
    frontend_ip_configuration_name = local.public_frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.public_listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 1
  }

  #ignore changes since AGW is managed by AGIC
  lifecycle {
    ignore_changes = [
      tags,
      backend_address_pool,
      backend_http_settings,
      frontend_port,
      http_listener,
      probe,
      redirect_configuration,
      request_routing_rule,
      ssl_certificate
    ]
  }
}


output "id" {
  value = azurerm_application_gateway.agw.id
}
output "name" {
  value = azurerm_application_gateway.agw.name
}