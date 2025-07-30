# variable "postgres_pv_name" {
#   type        = string
#   description = "The peristent volume to make cloudnative-pg store its data in."
# }
# variable "postgres_pvc_name" {
#   type        = string
#   description = "The peristentVolumeClaim to make cloudnative-pg use."
# }
variable "name" {
  type        = string
  default     = "cnpg"
  description = "The name of the cloudnative-pg operator."
}

resource "helm_release" "cloudnativepg" {
  name             = var.name
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = "0.25.0"
  namespace        = "cnpg-system"
  create_namespace = true

  set = [
    # {
    #   name  = "storageClass"
    #   value = "default"
    # },
    {
      name  = "resources.requests.ephemeral-storage"
      value = "1Gi"
    }
  ]
}
