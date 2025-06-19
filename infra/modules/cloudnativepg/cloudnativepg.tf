
variable "rg_name" {
  type = string
}
variable "location" {
  type = string
}
variable "postgres_pv_name" {
  type = string
}
variable "postgres_pvc_name" {
  type = string
}
variable "name" {
  type    = string
  default = "cnpg"
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
