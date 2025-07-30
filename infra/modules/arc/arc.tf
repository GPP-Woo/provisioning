# Assumes you already have a resource "azurerm_kubernetes_cluster" "aks" defined
# and a resource for your bastion host's public IP.

# provider "kubernetes" {
#   # The host is the localhost endpoint for your SSH tunnel.
#   # The FQDN of the private cluster is required for TLS certificate validation.

# #   host                   = "https://localhost:8443"
# #   cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
# #   client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
# #   client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)

#   # config_path = azurerm_kubernetes_cluster.main.kube_config_raw
#   host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
#   # username               = azurerm_kubernetes_cluster.main.kube_config[0].username
#   # password               = azurerm_kubernetes_cluster.main.kube_config[0].password
#   client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
#   client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
#   cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
#   # This section is optional but recommended. It bypasses the proxy for Azure API calls
#   # while ensuring Kubernetes API calls go through it.
#   proxy_url = "socks5://localhost:8180"
# }


# provider "helm" {
#   # The helm provider inherits its configuration from the kubernetes provider.
#   # Explicitly defining it ensures clarity and proper dependency handling.
#   kubernetes = {
#     # config_path = azurerm_kubernetes_cluster.main.kube_config_raw
#     host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
#     username               = azurerm_kubernetes_cluster.main.kube_config[0].username
#     password               = azurerm_kubernetes_cluster.main.kube_config[0].password
#     client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
#     client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
#     cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
#     proxy_url = "socks5://localhost:8180"
#   }
# }


# provider "helm" {
#   # The helm provider inherits its configuration from the kubernetes provider.
#   # Explicitly defining it ensures clarity and proper dependency handling.
#   kubernetes {
#     host                   = "https://localhost:8443"
#     cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
#     client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
#     client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)

#     proxy_url = "https://localhost:8443"
#   }
# }

# Add the Helm repository for the Actions Runner Controller
resource "helm_release" "arc" {
  # Depends on the AKS cluster being ready
  depends_on = [azurerm_kubernetes_cluster.aks]

  name       = "actions-runner-controller"
  repository = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart      = "gha-runner-scale-set-controller"
  namespace  = "actions-runner-system"

  create_namespace = true

  # Set any specific values for the ARC Helm chart here.
  # For example, to use your own GitHub App credentials.
  # set {
  #   name  = "github_app_id"
  #   value = var.github_app_id
  # }
  # set {
  #   name  = "github_app_installation_id"
  #   value = var.github_app_installation_id
  # }
  # set {
  #   name      = "github_app_private_key"
  #   value     = var.github_app_private_key
  #   sensitive = true
  # }
}