variable "environment" {
  description = "Environment suffix used for all resources"
  type        = string
  default     = ""
}
variable "project_name" {
  description = "Project name used for all resources"
  type        = string
  default     = "woo"
}

variable "location" {
  description = "The Azure Region in which all resources should be provisioned"
  type        = string
}
variable "rg_name" {
  description = "Resource Group Name"
  type        = string
  default     = null
}
variable "acr_name" {
  description = "Azure Container Registry Name"
  type        = string
  default     = null
}
variable "aks_name" {
  description = "Azure Kubernetes Service Cluster Name"
  type        = string
  default     = null
}

# variable "storage_account_name" {
#   description = "Storage Account Name"
#   type        = string
#   default     = "woo"
# }

# variable "postgres_pv_name" {
#   description = "Postgres Persistent Volume Name"
#   type        = string
# }

# variable "postgres_pvc_name" {
#   description = "Postgres Persistent Volume Claim Name"
#   type        = string
# }
