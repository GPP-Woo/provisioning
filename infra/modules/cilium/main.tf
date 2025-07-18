provider "helm" {
  kubernetes = {
    # config_path = azurerm_kubernetes_cluster.main.kube_config_raw
    host                   = azurerm_kubernetes_cluster.main.kube_config[0].host
    username               = azurerm_kubernetes_cluster.main.kube_config[0].username
    password               = azurerm_kubernetes_cluster.main.kube_config[0].password
    client_certificate     = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  }
}

resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.17.5"

  set = [
    {
      name  = "kubeProxyReplacement"
      value = "true"
    },
    # {
    #   name  = "tunnel"
    #   value = "disabled"
    # }
    # ,
    {
      name  = "autoDirectNodeRoutes"
      value = "true"
    }
    ,
    {
      name  = "azure.enabled"
      value = "true"
    }
    ,
    {
      name  = "azure.resourceGroup"
      value = var.rg_name
    }
    # ,
    # {
    #   name  = "azure.subscriptionID"
    #   value = var.subscription_id
    # }
    # ,
    # {
    #   name  = "azure.tenantID"
    #   value = var.tenant_id
    # }
    # ,
    # {
    #   name  = "azure.clientID"
    #   value = var.client_id
    # }
    # ,
    # {
    #   name  = "azure.clientSecret"
    #   value = var.client_secret
    # }
  ]
  # values = [
  #   {
  #     global = {
  #       enabled = true
  #     }
  #     nodeinit = {
  #       enabled = true
  #     }
  #     kubeProxyReplacement = "strict"
  #     hostServices = {
  #       enabled = true
  #     }
  #     externalIPs = {
  #       enabled = true
  #     }
  #     nodePort = {
  #       enabled = true
  #     }
  #     hostPort = {
  #       enabled = true
  #     }
  #     bandwidthManager = {
  #       enabled = true
  #     }
  #     eni = {
  #       enabled = false
  #     }
  #     azure = {
  #       enabled = true
  #     }
  #     ipv4 = {
  #       enabled = true
  #     }
  #     ipv6 = {
  #       enabled = false
  #     }
  #     tunnel               = "disabled"
  #     autoDirectNodeRoutes = true
  #     kubeProxyReplacement = "strict"
  #     hostServices = {
  #       enabled = true
  #     }
  #     externalIPs = {
  #       enabled = true
  #     }
  #     nodePort = {
  #       enabled = true
  #     }
  #     hostPort = {
  #       enabled = true
  #     }
  #     bandwidthManager = {
  #       enabled = true
  #     }
  #     eni = {
  #       enabled = false
  #     }
  #     azure = {
  #       enabled = true
  #     }
  #     ipv4 = {
  #       enabled = true
  #     }
  #     ipv6 = {
  #       enabled = false
  #     }
  #     tunnel               = "disabled"
  #     autoDirectNodeRoutes = true
  #   }
  # ]
}

