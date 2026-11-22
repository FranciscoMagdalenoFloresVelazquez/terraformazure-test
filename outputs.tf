output "public_ip" {
  description = "IP pública de la VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "web_url" {
  description = "URL de la página web"
  value       = "https://${azurerm_public_ip.pip.ip_address}"
}

output "ssh_command" {
  description = "Comando para conectarte a la VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}
