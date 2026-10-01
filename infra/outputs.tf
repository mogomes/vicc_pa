output "app_url" {
  description = "Öffentliche HTTPS-URL der Webapplikation (Browser)."
  value       = "https://${azurerm_container_app.web.latest_revision_fqdn}"
}

output "api_url" {
  description = "Basis-URL der Web-API."
  value       = "https://${azurerm_container_app.web.latest_revision_fqdn}/api/items"
}

output "resource_group" {
  description = "Name der Resource Group."
  value       = azurerm_resource_group.main.name
}

output "sql_server_fqdn" {
  description = "FQDN des Azure SQL Servers."
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name der Datenbank."
  value       = azurerm_mssql_database.main.name
}

output "sql_admin_password" {
  description = "Generiertes SQL-Admin-Passwort (nur bei Bedarf mit terraform output -raw abrufen)."
  value       = random_password.sql.result
  sensitive   = true
}
