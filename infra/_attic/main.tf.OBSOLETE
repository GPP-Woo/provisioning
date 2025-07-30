provider "azurerm" {
  # subscription_id = "Please setup .env file or set ARM_SUBSCRIPTION_ID environment value"
  features {}
}
variable "location" {
  description = "Azure Region"
  type        = string
  default     = "West Europe"
}
variable "rg_name" {
  description = "Resource Group Name"
  type        = string
  default     = "woo-aks"
}
variable "acr_name" {
  description = "Azure Container Registry Name"
  type        = string
  default     = "wooRegistry"
}

variable "aks_name" {
  description = "Azure Kubernetes Service Cluster Name"
  type        = string
  default     = "woo"
}

variable "storage_account_name" {
  description = "Storage Account Name"
  type        = string
  default     = "woo"
}

# variable "postgres_pv_name" {
#   description = "Postgres Persistent Volume Name"
#   type        = string
# }

# variable "postgres_pvc_name" {
#   description = "Postgres Persistent Volume Claim Name"
#   type        = string
# }


module "resource_group" {
  source   = "./modules/rg"
  name     = var.rg_name
  location = var.location
}
module "acr" {
  source   = "./modules/acr"
  name     = var.acr_name
  location = var.location
  rg_name  = var.rg_name
}

# module "aks" {
#   source   = "./modules/aks"
#   name     = var.aks_name
#   location = var.location
#   rg_name  = var.rg_name
# }

# module "storage" {
#   source   = "./modules/storage"
#   name     = var.storage_account_name
#   location = var.location
#   rg_name  = var.rg_name
# }

# module "cloudnativepg" {
#   source            = "./modules/cloudnativepg"
#   rg_name           = var.rg_name
#   location          = var.location
#   postgres_pv_name  = var.postgres_pv_name
#   postgres_pvc_name = var.postgres_pvc_name
# }

