
variable "rg_name" {
  type = string
}
variable "location" {
  type = string
}
variable "name" {
  type = string
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.rg_name
  dns_prefix          = "aksdns"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "none"
    network_policy    = "calico"
    load_balancer_sku = "standard"
  }

  # addon_profile {
  #   kube_dashboard {
  #     enabled = false
  #   }
  # }


  tags = {
    Environment = "Development"
  }

}

provider "helm" {
  kubernetes {
    config_path = azurerm_kubernetes_cluster.main.kube_config[0]
  }
}

resource "helm_release" "cilium" {

  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.10.5"

  
 set {
 name = "kubeProxyReplacement"
 value = "strict"
 }

 set {
 name = "tunnel"
 value = "disabled"
 }

 set {
 name = "autoDirectNodeRoutes"
 value = "true"
 }

 set {
 name = "azure.enabled"
 value = "true"
 }

 set {
 name = "azure.resourceGroup"
 value = var.rg_name
 }

 set {
 name = "azure.subscriptionID"
 value = var.subscription_id
 }

 set {
 name = "azure.tenantID"
 value = var.tenant_id
 }

 set {
 name = "azure.clientID"
 value = var.client_id
 }

 set {
 name = "azure.clientSecret"
 value = var.client_secret
 }

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

