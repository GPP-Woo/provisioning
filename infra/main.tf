terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.37.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.2"
    }
  }
}
provider "azurerm" {
  # Please setup OIDC or ARM_SUBSCRIPTION_ID environment value
  features {}
  # Terraform/OpenTofu reuse `az login` session when no explicit
  # credentials (client_id, client_secret, etc.) are provided.
  #  subscription_id = "<Your_Dev_Subscription_ID>"
  #  tenant_id       = "<Your_Dev_Tenant_ID>"
}
provider "kubernetes" {
  # The FQDN of the private cluster is required for TLS certificate validation.
  # config_path = azurerm_kubernetes_cluster.main.kube_config_raw
  # username               = module.aks.kube_config.username
  # password               = module.aks.kube_config.password
  host                   = module.aks.kube_config.host
  client_certificate     = base64decode(module.aks.kube_config.client_certificate)
  client_key             = base64decode(module.aks.kube_config.client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_config.cluster_ca_certificate)
  proxy_url              = "socks5://localhost:${var.SOCKS_PORT}"
}
provider "helm" {
  # The helm provider inherits its configuration from the kubernetes provider.
  # Explicitly defining it ensures clarity and proper dependency handling.
  kubernetes = {
    # config_path = azurerm_kubernetes_cluster.main.kube_config_raw
    # username               = module.aks.kube_config.username
    # password               = module.aks.kube_config.password
    host                   = module.aks.kube_config.host
    client_certificate     = base64decode(module.aks.kube_config.client_certificate)
    client_key             = base64decode(module.aks.kube_config.client_key)
    cluster_ca_certificate = base64decode(module.aks.kube_config.cluster_ca_certificate)
    proxy_url              = "socks5://localhost:${var.SOCKS_PORT}"
  }
}

locals {
  prefix = "${var.project_name}${var.environment}"
}

# Create one Resource Group to hold everything
resource "azurerm_resource_group" "rg" {
  name     = coalesce(var.rg_name, "rg-${local.prefix}-${var.locationcode}")
  location = var.location
}

# Create internal, private VNET for cluster, ACR endpoint, etc.
module "vnets" {
  source            = "./modules/vnets"
  prefix            = local.prefix
  hub_name          = "vnet-${local.prefix}-hub"
  aks_name          = "vnet-${local.prefix}-aks"
  location          = azurerm_resource_group.rg.location
  rg_name           = azurerm_resource_group.rg.name
  tags              = var.resource_tag_values
  hub_address_space = "10.0.0.0/16"
  bastion_subnet    = "10.0.0.0/27"
  global_subnet     = "10.0.1.0/24"
  aks_address_space = "10.1.0.0/16"
  agw_subnet        = "10.1.0.0/24"
  utils_subnet      = "10.1.2.0/24"
  aks_subnet        = "10.1.4.0/22"
}

# Create Azure Container Registry with optional Private Endpoint in private subnet
module "acr" {
  source                        = "./modules/acr"
  prefix                        = local.prefix
  name                          = coalesce(var.acr_name, "${local.prefix}pvaks${var.locationcode}")
  location                      = azurerm_resource_group.rg.location
  rg_name                       = azurerm_resource_group.rg.name
  tags                          = var.resource_tag_values
  sku                           = "Premium"
  admin_enabled                 = true
  private_endpoint_enabled      = true
  private_endpoint_subnetid     = module.vnets.snet_global_id
  aks_vnet_id                   = module.vnets.vnet_aks_id
  hub_vnet_id                   = module.vnets.vnet_hub_id
  public_network_access_enabled = false
}

# Create Application Gateway, managed by AKS with AGIC addon. It will have a private
# IP address set by us, and a public IP address assigned from Microsoft Azure.
module "agw" {
  source             = "./modules/agw"
  prefix             = local.prefix
  name               = coalesce(var.acr_name, "agw-${local.prefix}-pvaks-${var.locationcode}")
  location           = azurerm_resource_group.rg.location
  rg_name            = azurerm_resource_group.rg.name
  tags               = var.resource_tag_values
  subnet_id          = module.vnets.snet_agw_id
  private_ip_address = "10.1.0.4"
}

# Provision a Log Analytics Workspace:
module "law" {
  source   = "./modules/law"
  name     = coalesce(var.law_name, "law-${local.prefix}-pvaks-${var.locationcode}")
  location = azurerm_resource_group.rg.location
  rg_name  = azurerm_resource_group.rg.name
  tags     = var.resource_tag_values
}

# Setup our private AKS cluster:
module "aks" {
  source             = "./modules/aks"
  prefix             = local.prefix
  name               = coalesce(var.aks_name, "aks-${local.prefix}-${var.locationcode}")
  location           = azurerm_resource_group.rg.location
  rg_name            = azurerm_resource_group.rg.name
  aks_subnet_id      = module.vnets.snet_aks_id
  vnet_aks_id        = module.vnets.vnet_aks_id
  vnet_hub_id        = module.vnets.vnet_hub_id
  service_cidr       = "10.1.3.0/24"
  dns_service_ip     = "10.1.3.4"
  law_id             = module.law.id
  agw_id             = module.agw.id
  acr_id             = module.acr.id
  rg_id              = azurerm_resource_group.rg.id
  kubernetes_version = var.kubernetes_version
  node_pools = [
    {
      name       = "default"
      vm_size    = "Standard_DS2_v2"
      node_count = 3
    },
    # {
    #   name       = "user"
    #   vm_size    = "Standard_DS2_v2"
    #   node_count = 2
    # }
  ]
}

# Provision a MS Container Insights into Analytics Workspace:
module "msci" {
  source       = "./modules/msci"
  name         = "mcsi-${local.prefix}-pvaks-${var.locationcode}"
  prefix       = local.prefix
  location     = azurerm_resource_group.rg.location
  rg_name      = azurerm_resource_group.rg.name
  tags         = var.resource_tag_values
  cluster_id   = module.aks.id
  cluster_name = module.aks.name
  law_id       = module.law.id
}


# Add a Key Vault, accessible for pods:
module "kv" {
  source           = "./modules/kv"
  name             = "kv-${local.prefix}-pvaks-${var.locationcode}"
  location         = azurerm_resource_group.rg.location
  locationcode     = var.locationcode
  rg_name          = azurerm_resource_group.rg.name
  tags             = var.resource_tag_values
  prefix           = local.prefix
  pod_principal_id = module.aks.pod_principal_id
  vnet_aks_id      = module.vnets.vnet_aks_id
  vnet_hub_id      = module.vnets.vnet_hub_id
  snet_utils_id    = module.vnets.snet_utils_id
}

# Add a Bastion and optional VM:
module "bastion" {
  source          = "./modules/bastion"
  name            = "bastion-${local.prefix}-${var.locationcode}"
  location        = azurerm_resource_group.rg.location
  rg_name         = azurerm_resource_group.rg.name
  tags            = var.resource_tag_values
  prefix          = local.prefix
  snet_global_id  = module.vnets.snet_global_id
  snet_bastion_id = module.vnets.snet_bastion_id
  vm_username     = var.vm_username
  k8s_io_version  = join("", regex("^(\\d+\\.\\d+)(?:\\.\\d+)", var.kubernetes_version))
  kube_config_raw = module.aks.kube_config_raw
}

# module "storage" {
#   source   = "./modules/storage"
#   name     = "${local.prefix}-sa"
#   location = azurerm_resource_group.rg.location
#   rg_name  = azurerm_resource_group.rg.name
# }

# module "cloudnativepg" {
#   source            = "./modules/cloudnativepg"
#   rg_name           = azurerm_resource_group.rg.name
#   location          = azurerm_resource_group.rg.location
#   postgres_pv_name  = "${local.prefix}-cnpg-pv"
#   postgres_pvc_name = "${local.prefix}-cnpg-pvc"
# }

# this could be modularized:
data "azurerm_client_config" "current" {}
resource "azurerm_key_vault" "cisecrets" {
  name                          = coalesce(var.ci_vault_name, "kv-${local.prefix}-cisecrets-${var.locationcode}")
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  tags                          = var.resource_tag_values
  sku_name                      = "standard"
  enable_rbac_authorization     = false
  public_network_access_enabled = true
  purge_protection_enabled      = false
}
# Even this presents a race condition: https://github.com/hashicorp/terraform-provider-azurerm/issues/17015
# MS Azure is SUCH a mess - even Microsoft admits it:
#   Azure Rest API suggests to handle this by adding periodic retry logic if we
#   receive a 403 Error immediately after adding an identity to the access policy.
#   Not sure if Terraform resource code has such logic embedded into it.
#  https://docs.microsoft.com/en-us/azure/key-vault/general/rest-error-codes#http-403-insufficient-permissions
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id       = azurerm_key_vault.cisecrets.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  key_permissions    = ["Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore"]
  secret_permissions = ["Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"]
}
# Unfortunately, relying on newly assigned RBAC roles presents this race condition, so we
# must use above legacy Access Policies for now. Using RBAC leads to below errors during provisioning.
# │ Error: checking for presence of existing Secret "vm-privkey" (Key Vault "https://kv-devwoo-cisecrets-weu.vault.azure.net/"): keyvault.BaseClient#GetSecret: Failure responding to request: StatusCode=403 -- Original Error: autorest/azure: Service returned an error. Status=403 Code="Forbidden" Message="Caller is not authorized to perform action on resource.\r\nIf role assignments, deny assignments or role definitions were changed recently, please observe propagation time.
# For role_definition_id values, see:
# https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide
# resource "azurerm_role_assignment" "akv_sp" {
#   scope              = azurerm_key_vault.cisecrets.id
#   principal_id       = data.azurerm_client_config.current.object_id
#   # role_definition_id = "b86a8fe4-44ce-4948-aee5-eccb2c155cd7"
#   # role_definition_name = "Key Vault Secrets Officer"
#   role_definition_id = "00482a5a-887f-4fb3-b363-3b7fe8e74483"
#   # role_definition_name = "Key Vault Administrator"
# }
resource "azurerm_key_vault_secret" "vm_privkey" {
  name         = "vm-privkey"
  key_vault_id = azurerm_key_vault.cisecrets.id
  value        = module.bastion.vm_privatekey
  depends_on   = [azurerm_key_vault_access_policy.current_user]
}
resource "azurerm_key_vault_secret" "aks_kubeconfig" {
  name         = "aks-kubeconfig"
  key_vault_id = azurerm_key_vault.cisecrets.id
  value        = module.aks.kube_config_raw
  depends_on   = [azurerm_key_vault_access_policy.current_user]
}


# AKS/Kubernetes resources to follow

module "cnpg" {
  source = "./modules/cnpg/"
}

variable "ISSUER_EMAIL" {
  type        = string
  description = "cert manager cluster issuer email"
  default     = "certificate@info.nl"
}
resource "helm_release" "cert-manager" {
  count            = 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.18.2"
  create_namespace = true
  namespace        = "cert-manager"
  cleanup_on_fail  = true
  set = [{
    name  = "installCRDs"
    value = true
  }]
}
# resource "kubernetes_manifest" "clusterissuer_letsencrypt_prod" {
#   depends_on = [
#     helm_release.cert-manager
#   ]
#   manifest = {
#     "apiVersion" = "cert-manager.io/v1"
#     "kind" = "ClusterIssuer"
#     "metadata" = {
#       "name" = "letsencrypt-prod"
#     }
#     "spec" = {
#       "acme" = {
#         "email" = var.ISSUER_EMAIL
#         "privateKeySecretRef" = {
#           "name" = "letsencrypt-prod"
#         }
#         "server" = "https://acme-v02.api.letsencrypt.org/directory"
#         "solvers" = [
#           {
#             "http01" = {
#               "ingress" = {
#                 "ingressClassName" = "nginx"
#               }
#             }
#           }
#         ]
#       }
#     }
#   }
# }

resource "helm_release" "nginx_ingress" {
  count      = 0
  name       = "nginx-ingress-controller"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"

  set = [{
    name  = "service.type"
    value = "ClusterIP"
  }]
}
# Add the Helm repository for the Actions Runner Controller
# resource "helm_release" "arc" {
#   # Depends on the AKS cluster being ready
#   depends_on = [module.aks.private_fqdn]

#   name       = "actions-runner-controller"
#   repository = "https://actions-runner-controller.github.io/actions-runner-controller"
#   chart      = "gha-runner-scale-set-controller"
#   namespace  = "actions-runner-system"

#   create_namespace = true

#   # Set any specific values for the ARC Helm chart here.
#   # For example, to use your own GitHub App credentials.
#   # set {
#   #   name  = "github_app_id"
#   #   value = var.github_app_id
#   # }
#   # set {
#   #   name  = "github_app_installation_id"
#   #   value = var.github_app_installation_id
#   # }
#   # set {
#   #   name      = "github_app_private_key"
#   #   value     = var.github_app_private_key
#   #   sensitive = true
#   # }
# }


output "rg_name" {
  value = azurerm_resource_group.rg.name
}
output "aks" {
  value     = module.aks
  sensitive = true
}
output "aks_id" {
  value = module.aks.id
}
output "aks_kubeconfig" {
  value     = module.aks.kube_config
  sensitive = true
}
output "aks_kubeconfig_raw" {
  value     = module.aks.kube_config_raw
  sensitive = true
}
output "aks_private_fqdn" {
  value = module.aks.private_fqdn
}
output "bastion_name" {
  value = module.bastion.bastion_name
}
output "bastion_ip" {
  value = module.bastion.bastion_ip
}
output "vm_username" {
  value = module.bastion.vm_username
}
output "vm_password" {
  value     = module.bastion.vm_password
  sensitive = true
}
output "vm_privkey" {
  value     = module.bastion.vm_privatekey
  sensitive = true
}
output "vm1_id" {
  value = module.bastion.vm1_id
}
output "vm1_ip" {
  value = module.bastion.vm1_ip
}
output "vm1_access_howto" {
  value     = module.bastion.vm1_access_howto
  sensitive = true
}
output "vm2_ip" {
  value = module.bastion.vm2_ip
}