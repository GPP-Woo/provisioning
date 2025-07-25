
variable "rg_name" {
  type        = string
  description = "The name of the resource group in which to create the AKS cluster."
}
variable "location" {
  type        = string
  description = "The Azure location where the AKS cluster should exist."
}
variable "prefix" {
  type        = string
  description = "String to insert in resources, e.g. <resource>-<prefix>-<use>"
}
variable "name" {
  type        = string
  description = "The name of the AKS cluster."
}
variable "kubernetes_version" {
  type        = string
  default     = null
  description = "AKS K8s Version"
}
locals {
  template_node_pool = {
    name       = "default"
    vm_size    = "Standard_DS2_v2"
    node_count = 1
    upgrade_settings = {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }
}
variable "node_pools" {
  type = list(object({
    name       = string
    vm_size    = string
    node_count = number
    upgrade_settings = optional(object({
      drain_timeout_in_minutes      = number
      max_surge                     = string
      node_soak_duration_in_minutes = number
    }))
  }))
  description = "The list of node_pools and configs"
  default = [
    {
      name       = "default"
      vm_size    = "Standard_DS2_v2"
      node_count = 1
      upgrade_settings = {
        drain_timeout_in_minutes      = 0
        max_surge                     = "10%"
        node_soak_duration_in_minutes = 0
      }
    }
  ]
}
variable "vnet_hub_id" {
  type        = string
  description = "The HUB vnet_id to connect nodes to"
}
variable "vnet_aks_id" {
  type        = string
  description = "The AKS vnet_id to connect nodes to"
}
variable "aks_subnet_id" {
  type        = string
  description = "The AKS subnet_id to connect nodes to"
}
variable "service_cidr" {
  type        = string
  description = "CIDR for local services, e.g. DNS"
  default     = "10.1.3.0/24"
}
variable "dns_service_ip" {
  type        = string
  description = "The IP address for the cluster DNS service (must be on service_cidr)"
  default     = "10.1.3.4"
}
variable "tags" {
  type = map(string)
  default = {
    # Provisioner = "Terraform"
    # Environment = "<not set>"
  }
  description = "The list of tags (tag/value) to add to created resources."
}
variable "law_id" {
  type        = string
  default     = null
  description = "Log Analytics Workspace ID for OMS agent (optional)"
}
variable "agw_id" {
  type        = string
  description = "The Application Gateway ID to integrate with AKS using AGIC"
}
variable "acr_id" {
  type        = string
  description = "The Azure Container Registry ID to setup Role Assignments for"
}
variable "rg_id" {
  type        = string
  description = "The Resource Group ID to setup Role Assignments for"
}

locals {
  # The first node_pool in node_pools[] MUST be the default node pool
  default_node_pool = merge(
    local.template_node_pool,
    var.node_pools[0],
    {
      upgrade_settings = merge(
        local.template_node_pool.upgrade_settings,
        try(var.node_pools[0].upgrade_settings, {})
      )
    }
  )
  extra_node_pools = {
    for pool in slice(var.node_pools, 1, length(var.node_pools)) :
    pool.name => merge(
      local.template_node_pool,
      pool,
      {
        upgrade_settings = merge(
          local.template_node_pool.upgrade_settings,
          try(pool.upgrade_settings, {})
        )
      }
    )
  }
}


### DNS zone
resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.westeurope.azmk8s.io"
  resource_group_name = var.rg_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks1" {
  name                  = "pdzvnl-${var.prefix}aks-001" # "pdzvnl-aks-cac-001"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = var.vnet_hub_id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks2" {
  name                  = "pdzvnl-${var.prefix}aks-002" # "pdzvnl-aks-weu-002"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = var.vnet_aks_id
  tags                  = var.tags
}

### Identity
resource "azurerm_user_assigned_identity" "aks" {
  name                = "uaid-${var.prefix}aks-001" # "id-aks-weu-001"
  resource_group_name = var.rg_name
  location            = var.location
  tags                = var.tags
}
resource "azurerm_user_assigned_identity" "pod" {
  name                = "uaid-${var.prefix}pod-001" # "id-pod-weu-001"
  resource_group_name = var.rg_name
  location            = var.location
  tags                = var.tags
}

### Identity role assignment
resource "azurerm_role_assignment" "dns_contributor" {
  scope                = azurerm_private_dns_zone.aks.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "network_contributor" {
  scope                = var.vnet_aks_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "acr" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "agw" {
  scope                = var.rg_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

# Open issue https://github.com/hashicorp/terraform-provider-azurerm/issues/21305 causes msi_auth 
# to result in missing state date for azurerm_kubernetes_cluster.oms_agent[0].oms_agent_identity - and:
#
# │ Error: Invalid index
# │
# │   on ../../modules/aks/main.tf line 196, in resource "azurerm_role_assignment" "monitoring":
# │  196:   principal_id         = azurerm_kubernetes_cluster.main.oms_agent[0].oms_agent_identity[0].object_id
# │     ├────────────────
# │     │ azurerm_kubernetes_cluster.main.oms_agent[0].oms_agent_identity is empty list of object
#
# resource "azurerm_role_assignment" "monitoring" {
#   scope                = azurerm_kubernetes_cluster.main.id
#   role_definition_name = "Monitoring Metrics Publisher"
#   principal_id         = azurerm_kubernetes_cluster.main.oms_agent[0].oms_agent_identity[0].object_id
# }

### AKS cluster creation

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.name # "aks-<project>-weu-001"
  location            = var.location
  resource_group_name = var.rg_name
  # dns_prefix          = var.name
  dns_prefix_private_cluster = var.name
  private_cluster_enabled    = true
  private_dns_zone_id        = azurerm_private_dns_zone.aks.id
  kubernetes_version         = var.kubernetes_version
  tags                       = var.tags

  # identity {
  #   type = "SystemAssigned"
  # }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }
  default_node_pool {
    name           = local.default_node_pool.name
    node_count     = local.default_node_pool.node_count
    vm_size        = local.default_node_pool.vm_size
    vnet_subnet_id = var.aks_subnet_id
    upgrade_settings {
      drain_timeout_in_minutes      = local.default_node_pool.upgrade_settings.drain_timeout_in_minutes
      max_surge                     = local.default_node_pool.upgrade_settings.max_surge
      node_soak_duration_in_minutes = local.default_node_pool.upgrade_settings.node_soak_duration_in_minutes
    }
  }
  # network_profile {
  #   network_plugin = "none"
  #   # network_policy    = "calico"
  #   load_balancer_sku = "standard"
  # }
  network_profile {
    network_plugin = "azure"
    dns_service_ip = var.dns_service_ip
    service_cidr   = var.service_cidr
    #docker_bridge_cidr = "172.16.0.1/16" # No longer relevant since AKS 1.19 switched to containerd runtime
  }
  ingress_application_gateway {
    gateway_id = var.agw_id
  }

  dynamic "oms_agent" {
    for_each = var.law_id != null ? [1] : []
    content {
      log_analytics_workspace_id      = var.law_id
      msi_auth_for_monitoring_enabled = true
    }
  }
  # With var.law_id set, this generates:
  # oms_agent {
  #   log_analytics_workspace_id = var.law_id
  #   msi_auth_for_monitoring_enabled = true
  # }

  depends_on = [
    azurerm_role_assignment.network_contributor,
    azurerm_role_assignment.dns_contributor
  ]

  # addon_profile {
  #   kube_dashboard {
  #     enabled = false
  #   }
  # }
}
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = local.extra_node_pools

  name                  = each.value.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = each.value.vm_size
  tags                  = var.tags
  node_count            = each.value.node_count
  vnet_subnet_id        = var.aks_subnet_id
  upgrade_settings {
    drain_timeout_in_minutes      = each.value.upgrade_settings.drain_timeout_in_minutes
    max_surge                     = each.value.upgrade_settings.max_surge
    node_soak_duration_in_minutes = each.value.upgrade_settings.node_soak_duration_in_minutes
  }
}

output "id" {
  value = azurerm_kubernetes_cluster.main.id
}
output "name" {
  value = azurerm_kubernetes_cluster.main.name
}
output "client_certificate" {
  value     = azurerm_kubernetes_cluster.main.kube_config[0].client_certificate
  sensitive = true
}
output "kube_config" {
  value     = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}
output "pod_principal_id" {
  value = azurerm_user_assigned_identity.pod.principal_id
}
