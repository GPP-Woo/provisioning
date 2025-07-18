# Use MS CI guideline for adding MS CI to AKS:
# - https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable?tabs=terraform
# - https://github.com/microsoft/Docker-Provider/tree/ci_prod/scripts/onboarding/aks/onboarding-msi-terraform

variable "rg_name" {
  type        = string
  description = "The name of the resource group in which to create the vnets, subnets and network-peerings."
}
variable "location" {
  type        = string
  description = "The Azure location where the vnet resources should exist."
}
variable "prefix" {
  type        = string
  description = "String to insert in resources, e.g. vnet-<prefix>-<name>"
}
variable "name" {
  type        = string
  description = "The name of the Application Gateway."
}

variable "law_id" {
  type        = string
  default     = null
  description = "Log Analytics Workspace ID for OMS agent (optional)"
}
variable "cluster_id" {
  type        = string
  description = "AKS cluster ID, used as DCRA target"
}
variable "cluster_name" {
  type        = string
  description = "Name of the AKS cluster, to be tagged onto end of DCE and DCRA identifiers"
  default     = "pvaks"
}
variable "resource_tags" {
  description = "Resource Tag Values"
  type        = map(string)
  default     = null
  # default     = {
  #   "<existingOrnew-tag-name1>" = "<existingOrnew-tag-value1>"
  #   "<existingOrnew-tag-name2>" = "<existingOrnew-tag-value2>"
  #   "<existingOrnew-tag-name3>" = "<existingOrnew-tag-value3>"
  # }
}
variable "data_collection_interval" {
  type    = string
  default = "1m"
}
variable "namespace_filtering_mode_for_data_collection" {
  type    = string
  default = "Off"
}
variable "namespaces_for_data_collection" {
  type    = list(string)
  default = ["kube-system", "gatekeeper-system", "azure-arc"]
}
variable "enableContainerLogV2" {
  type    = bool
  default = true
}
variable "streams" {
  type = list(string)
  default = [
    "Microsoft-ContainerLog",
    "Microsoft-ContainerLogV2",
    "Microsoft-KubeEvents",
    "Microsoft-KubePodInventory",
    "Microsoft-KubeNodeInventory",
    "Microsoft-KubePVInventory",
    "Microsoft-KubeServices",
    "Microsoft-KubeMonAgentEvents",
    "Microsoft-InsightsMetrics",
    "Microsoft-ContainerInventory",
    "Microsoft-ContainerNodeInventory",
    "Microsoft-Perf"
  ]
}


locals {
  enable_high_log_scale_mode = contains(var.streams, "Microsoft-ContainerLogV2-HighScale")
  ingestion_dce_name_full    = "dce-ingest-${var.prefix}-${var.cluster_name}"
  ingestion_dce_name_trimmed = substr(local.ingestion_dce_name_full, 0, 43)
  ingestion_dce_name         = endswith(local.ingestion_dce_name_trimmed, "-") ? substr(local.ingestion_dce_name_trimmed, 0, 42) : local.ingestion_dce_name_trimmed
}

resource "azurerm_monitor_data_collection_endpoint" "ingestion_dce" {
  count               = local.enable_high_log_scale_mode ? 1 : 0
  name                = local.ingestion_dce_name
  resource_group_name = var.rg_name
  location            = var.location
  kind                = "Linux"
  tags                = var.resource_tags
}

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                = "dcr-${var.prefix}-${var.cluster_name}"
  resource_group_name = var.rg_name
  location            = var.location

  destinations {
    log_analytics {
      workspace_resource_id = var.law_id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = var.streams
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      streams        = var.streams
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        "dataCollectionSettings" : {
          "interval" : var.data_collection_interval,
          "namespaceFilteringMode" : var.namespace_filtering_mode_for_data_collection,
          "namespaces" : var.namespaces_for_data_collection
          "enableContainerLogV2" : var.enableContainerLogV2
        }
      })
      name = "ContainerInsightsExtension"
    }
  }

  data_collection_endpoint_id = local.enable_high_log_scale_mode ? azurerm_monitor_data_collection_endpoint.ingestion_dce[0].id : null

  description = "DCR for Azure Monitor Container Insights"
}

resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = var.cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
  description             = "Association of container insights data collection rule. Deleting this association will break the data collection for this AKS Cluster."
}