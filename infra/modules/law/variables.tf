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
variable "tags" {
  description = "Resource Tag Values"
  type        = map(string)
  # default     = {
  #   "<existingOrnew-tag-name1>" = "<existingOrnew-tag-value1>"
  #   "<existingOrnew-tag-name2>" = "<existingOrnew-tag-value2>"
  #   "<existingOrnew-tag-name3>" = "<existingOrnew-tag-value3>"
  # }
}