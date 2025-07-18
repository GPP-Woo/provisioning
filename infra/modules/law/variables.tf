variable "name" {
  type        = string
  description = "The name of the Log Analytics Workspace"
}
variable "rg_name" {
  type        = string
  description = "The name of the resource group in which to create the Log Analytics Workspace"
}
variable "location" {
  description = "The Azure Region in which all resources in this example should be provisioned"
}
variable "sku" {
  type        = string
  description = "The Azure Log Analytics Workspace type to provision"
  default     = "PerGB2018"
}
variable "retention_in_days" {
  type        = number
  description = "The log retention time in days"
  default     = 30
}