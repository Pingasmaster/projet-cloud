# Sorties utiles après le déploiement

output "ip_publique_vm" {
  description = "Adresse IP publique de la machine virtuelle"
  value       = azurerm_public_ip.ip_publique.ip_address
}

output "url_application" {
  description = "URL pour accéder à l'application Flask"
  value       = "http://${azurerm_public_ip.ip_publique.ip_address}:5000"
}

output "connexion_ssh" {
  description = "Commande SSH pour se connecter à la VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.ip_publique.ip_address}"
}

output "nom_compte_stockage" {
  description = "Nom du compte de stockage Azure"
  value       = azurerm_storage_account.stockage.name
}

output "nom_conteneur_blob" {
  description = "Nom du conteneur Blob Storage"
  value       = azurerm_storage_container.conteneur.name
}

output "db_hostname" {
  description = "Nom d'hôte du serveur PostgreSQL"
  value       = azurerm_postgresql_flexible_server.db.fqdn
}

output "db_nom" {
  description = "Nom de la base de données"
  value       = azurerm_postgresql_flexible_server_database.app_db.name
}
