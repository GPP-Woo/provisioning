variable "rg_name" {
  type        = string
  description = "The name of the resource group in which to create the Bastion."
}
variable "location" {
  type        = string
  description = "The Azure location where the vnet resources should exist."
}
variable "prefix" {
  type        = string
  description = "String to insert in resources, e.g. vnet-<prefix>-<name>"
}
variable "name" {
  type        = string
  description = "The name of the Bastion."
}
variable "snet_global_id" {
  type        = string
  description = "The Global subnet_id"
}
variable "snet_bastion_id" {
  type        = string
  description = "The Bastion subnet_id"
}

variable "vm_username" {
  type        = string
  description = "Username for vm-1"
  default     = "admin"
}
variable "vm_password" {
  type        = string
  sensitive   = true
  description = "Password for vm-1"
  default     = null
}
variable "enable_linux_vm" {
  type    = bool
  default = true
}
variable "enable_windows_vm" {
  type    = bool
  default = false
}
variable "kube_config" {
  type        = string
  sensitive   = true
  description = "Kubeconfig contents to install for <vm_username>"
  default     = null
}

resource "random_pet" "vm_password" {
  # keepers = {
  #   # Generate a new pet name each time we switch to a new AMI id
  #   ami_id = var.prefix
  # }
  length = 3
  prefix = "${var.prefix}%AKS"
}

locals {
  vm_password = coalesce(var.vm_password, random_pet.vm_password.id)
  custom_data = var.kube_config == null ? null : <<CUSTOM_DATA
#!/bin/bash
sudo -i
KC=/home/${var.vm_username}/.kube/config
mkdir /home/${var.vm_username}/.kube
cat << EOT > $KC
${var.kube_config}
EOT
chown -R ${var.vm_username}: /home/${var.vm_username}/.kube
chmod 0600 $KC
cat << EOF > /etc/customdata
${var.prefix} kubeconfig installed in /home/${var.vm_username}/.kube/config.
(Done.)
EOF
CUSTOM_DATA
}

# Setup a Bastion
resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.prefix}-bas-001"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"

}

resource "azurerm_bastion_host" "bastion" {
  name                = coalesce(var.name, "bas-${var.prefix}-001")
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "Standard"
  ip_connect_enabled  = true
  tunneling_enabled   = true
  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.snet_bastion_id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_interface" "vm1nic" {
  count               = var.enable_linux_vm ? 1 : 0
  name                = "nic-vm1"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.snet_global_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "vm2nic" {
  count               = var.enable_windows_vm ? 1 : 0
  name                = "nic-vm2"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.snet_global_id
    private_ip_address_allocation = "Dynamic"
  }
}


# Generate a throw-away keypair, for disctributing kubeadm join arguments
resource "tls_private_key" "vm1_ssh" {
  count     = var.enable_linux_vm ? 1 : 0
  algorithm = "ED25519"
  # rsa_bits  = 2048
}

resource "azurerm_linux_virtual_machine" "vm1" {
  count               = var.enable_linux_vm ? 1 : 0
  name                = "vm-linux"
  resource_group_name = var.rg_name
  location            = var.location
  size                = "Standard_F2"
  admin_username      = var.vm_username
  admin_password      = local.vm_password
  custom_data         = var.kube_config == null ? null : base64encode(local.custom_data)
  network_interface_ids = [
    azurerm_network_interface.vm1nic[0].id,
  ]

  admin_ssh_key {
    username   = var.vm_username
    public_key = tls_private_key.vm1_ssh[0].public_key_openssh #("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# SKU query:
#   az vm image list --output table --publisher MicrosoftWindowsDesktop --all --location westeurope
# Architecture Offer            Publisher Sku    Urn                                      UrnAlias   Version
# x64          ubuntu-24_04-lts Canonical server Canonical:ubuntu-24_04-lts:server:latest Ubuntu2404 latest
# And an optional VM
resource "azurerm_windows_virtual_machine" "vm2" {
  count               = var.enable_windows_vm ? 1 : 0
  name                = "vm-windows"
  resource_group_name = var.rg_name
  location            = var.location
  size                = "Standard_D2s_v3"
  admin_username      = var.vm_username
  admin_password      = local.vm_password
  network_interface_ids = [
    azurerm_network_interface.vm2nic[0].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-22h2-pro"
    version   = "latest"
  }
}

output "bastion" {
  value = azurerm_bastion_host.bastion.name
}
output "vm1_ip" {
  value = var.enable_linux_vm ? azurerm_linux_virtual_machine.vm1[0].private_ip_address : null
}
output "vm2_ip" {
  value = var.enable_windows_vm ? azurerm_windows_virtual_machine.vm2[0].private_ip_address : null
}
output "vm_password" {
  value = local.vm_password
}
output "vm_privatekey" {
  value = var.enable_linux_vm ? tls_private_key.vm1_ssh[0].private_key_openssh : null
}