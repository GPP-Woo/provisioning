
variable "rg_name" {
  type        = string
  description = "The name of the resource group in which to create the cloudnative-pg cluster."
}
variable "location" {
  type        = string
  description = "The Azure location where the cloudnative-pg cluster should exist."
}
variable "postgres_pv_name" {
  type        = string
  description = "The peristent volume to make cloudnative-pg store its data in."
}
variable "postgres_pvc_name" {
  type        = string
  description = "The peristentVolumeClaim to make cloudnative-pg use."
}
variable "name" {
  type        = string
  default     = "cnpg"
  description = "The name of the cloudnative-pg cluster."
}

resource "helm_release" "cloudnativepg" {
  name       = var.name
  repository = "https://cloudnative-pg.github.io/charts"
  chart      = "cloudnative-pg"
  version    = "0.8.0"
  namespace  = "default"

  set {
    name  = "storageClass"
    value = "default"
  }

  set {
    name  = "resources.requests.storage"
    value = "1Gi"
  }

}
