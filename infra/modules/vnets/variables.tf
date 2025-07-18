
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
variable "hub_name" {
  type        = string
  description = "The name of the hub vnet (default: hub)"
  default     = null
}
variable "agw_name" {
  type        = string
  description = "The name of the AGW vnet (default: agw)."
  default     = null
}
variable "aks_name" {
  type        = string
  description = "The name of the internal AKS vnet (default: aks)."
  default     = null
}
variable "global_name" {
  type        = string
  description = "The name of the Global vnet resources (default: global)."
  default     = null
}
variable "utils_name" {
  type        = string
  description = "The name of the internal Urils vnet (default: utils)."
  default     = null
}

variable "hub_address_space" {
  type        = string
  description = "Hub network address space (CIDR)"
}
variable "aks_address_space" {
  type        = string
  description = "Internal AKS network address space (CIDR)"
}
variable "agw_subnet" {
  type        = string
  description = "AppGw subnet (CIDR)"
}
variable "aks_subnet" {
  type        = string
  description = "Internal AKS subnet (CIDR)"
}
variable "bastion_subnet" {
  type        = string
  description = "Bastion subnet (CIDR)"
}
variable "global_subnet" {
  type        = string
  description = "Global subnet (CIDR)"
}
variable "utils_subnet" {
  type        = string
  description = "Utils subnet (CIDR)"
}
variable "hub_vnet_peering" {
  type        = string
  description = "Name of the HUB vnet peering"
  default     = "peer-to-vnet-hub"
}
variable "aks_vnet_peering" {
  type        = string
  description = "Name of the AKS vnet peering"
  default     = "peer-to-vnet-aks"
}

# variable "aks_subnet_address_prefix" {
# }

# variable "aks_subnet_address_name" {
# }

# variable "appgw_subnet_address_prefix" {
# }

# variable "appgw_subnet_address_name" {
# }


variable "environment" {
  type        = string
  description = "To be set as value for Environment tag"
  default     = null
}
