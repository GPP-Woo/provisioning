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
variable "k8s_io_version" {
  type        = string
  default     = "1.33"
  description = "pkgs.k8s.io repo version"
}
variable "kube_config_raw" {
  type        = string
  sensitive   = true
  description = "Kubeconfig contents to install for <vm_username>"
  default     = null
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

  custom_data = var.kube_config_raw == null ? null : <<CUSTOM_DATA
#!/bin/bash
sudo -i
KC=/home/${var.vm_username}/.kube/config
mkdir /home/${var.vm_username}/.kube
cat << EOT > $KC
${var.kube_config_raw}
EOT
chown -R ${var.vm_username}: /home/${var.vm_username}/.kube
chmod 0600 $KC
curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" \
  | tee /etc/apt/sources.list.d/helm-stable-debian.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${var.k8s_io_version}/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${var.k8s_io_version}/deb/ /' \
  | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubeadm kubectl helm # might pin versions, e.g. "=1.32.4-1.1"
cat << EOF > /etc/customdata
${var.prefix} kubeconfig installed in /home/${var.vm_username}/.kube/config.
(Done.)
EOF
CUSTOM_DATA

  ssh_access = var.enable_linux_vm == false ? null : <<SSH_ACCESS
tofu -chdir=infra output -raw -show-sensitive vm_privkey \
  | install -m 0600 /dev/stdin ~/.ssh/vm1-${var.vm_username}
cat <<PRIVKEY | install -m 0600 /dev/stdin ~/.ssh/vm1-${var.vm_username}
${tls_private_key.vm1[0].private_key_openssh}
PRIVKEY
az network bastion ssh --name ${azurerm_bastion_host.bastion.name} --resource-group ${var.rg_name} \
  --target-ip-address ${azurerm_linux_virtual_machine.vm1[0].private_ip_address} --username ${var.vm_username} \
  --auth-type ssh-key --ssh-key ~/.ssh/vm1-${var.vm_username}
SSH_ACCESS
}

# Setup a Bastion
resource "azurerm_public_ip" "bastion" {
  name                = "pip-${var.prefix}-bas-001"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "bastion" {
  name                = coalesce(var.name, "bas-${var.prefix}-001")
  location            = var.location
  resource_group_name = var.rg_name
  tags                = var.tags
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
  tags                = var.tags

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
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.snet_global_id
    private_ip_address_allocation = "Dynamic"
  }
}

# Generate a throw-away keypair, for disctributing kubeadm join arguments
resource "tls_private_key" "vm1" {
  count     = var.enable_linux_vm ? 1 : 0
  algorithm = "ED25519"
  # rsa_bits  = 2048
}
moved {
  from = tls_private_key.vm1_ssh
  to   = tls_private_key.vm1
}
resource "azurerm_linux_virtual_machine" "vm1" {
  count               = var.enable_linux_vm ? 1 : 0
  name                = "vm-linux"
  resource_group_name = var.rg_name
  location            = var.location
  size                = "Standard_F2"
  tags                = var.tags
  admin_username      = var.vm_username
  admin_password      = local.vm_password
  custom_data         = var.kube_config_raw == null ? null : base64encode(local.custom_data)
  network_interface_ids = [
    azurerm_network_interface.vm1nic[0].id,
  ]

  admin_ssh_key {
    username   = var.vm_username
    public_key = tls_private_key.vm1[0].public_key_openssh #("~/.ssh/id_rsa.pub")
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
  tags                = var.tags
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

output "bastion_name" {
  value = azurerm_bastion_host.bastion.name
}
output "bastion_ip" {
  value = azurerm_public_ip.bastion.ip_address
}
output "vm1_id" {
  value = var.enable_linux_vm ? azurerm_linux_virtual_machine.vm1[0].id : null
}
output "vm1_ip" {
  value = var.enable_linux_vm ? azurerm_linux_virtual_machine.vm1[0].private_ip_address : null
}
output "vm2_id" {
  value = var.enable_windows_vm ? azurerm_windows_virtual_machine.vm2[0].id : null
}
output "vm2_ip" {
  value = var.enable_windows_vm ? azurerm_windows_virtual_machine.vm2[0].private_ip_address : null
}
output "vm_username" {
  value = var.vm_username
}
output "vm_password" {
  value = local.vm_password
}
output "vm_privatekey" {
  value = var.enable_linux_vm ? tls_private_key.vm1[0].private_key_openssh : null
}
output "vm1_access_howto" {
  value = var.enable_linux_vm ? local.ssh_access : null
}
