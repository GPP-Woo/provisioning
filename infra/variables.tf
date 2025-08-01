variable "environment" {
  description = "Environment suffix used for all resources"
  type        = string
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
variable "locationcode" {
  description = "The Azure Region CODE (e.g. weu for West Europe)"
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
variable "kubernetes_version" {
  type        = string
  default     = "1.33.0"
  description = "Kubernetes version for AKS"
}
variable "aks_node_pools" {
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
      node_count = 2
    }
  ]
}
variable "law_name" {
  description = "Azure Log Analytics Workspace Name"
  type        = string
  default     = null
}
variable "vm_username" {
  type        = string
  description = "Username for bastion VM(s)"
  default     = "BastionUser"
  validation {
    condition     = !contains(["root", "bin", "operator", "user"], var.vm_username)
    error_message = "The (Linux) username MUST NOT clash with system-default groups. Choose another."
  }
}
# variable "vm_password" {
#   type = string
#   description = "Password for bastion VM users"
#   default = null
#   sensitive = true
# }

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

variable "resource_tag_values" {
  description = "Resource Tag Values"
  type        = map(string)
  default = {
    Provisioner = "Terraform"
    Environment = "<not set>"
    # "<existingOrnew-tag-name1>" = "<existingOrnew-tag-value1>"
  }
}

variable "ci_vault_name" {
  type        = string
  description = "The name of the keyvault to store CI secrets in, e.g. vm_privkey, kubeconfig, etc."
  default     = null
}
variable "SOCKS_PORT" {
  type        = number
  description = "The SOCKS5 (tcp) port number for the proxy to listen on (for k8s endpoint access)"
  default     = 8180
}