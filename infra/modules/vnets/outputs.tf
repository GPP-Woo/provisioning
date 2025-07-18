output "vnet_aks_id" {
  value = azurerm_virtual_network.vnet_aks.id
}
output "vnet_hub_id" {
  value = azurerm_virtual_network.vnet_hub.id
}

output "snet_agw_id" {
  value = azurerm_subnet.agw.id
}
output "snet_aks_id" {
  value = azurerm_subnet.aks.id
}
output "snet_bastion_id" {
  value = azurerm_subnet.bastion.id
}
output "snet_global_id" {
  value = azurerm_subnet.global.id
}
output "snet_utils_id" {
  value = azurerm_subnet.utils.id
}
