locals {
  name_prefix = "${var.project}-${var.environment}"
  tags        = merge(var.tags, { Environment = var.environment })
}

# --------------------------------------------------------------------------- #
# Eindeutige Namen / Secrets
# --------------------------------------------------------------------------- #
# Azure SQL Server-Namen müssen weltweit eindeutig sein.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# Das SQL-Passwort wird von Terraform generiert und nie im Klartext im Repository
# abgelegt. Es landet verschlüsselt im State und als Secret in der Container App.
resource "random_password" "sql" {
  length           = 24
  special          = true
  override_special = "!#%&*()-_=+[]{}<>:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

# --------------------------------------------------------------------------- #
# Basis
# --------------------------------------------------------------------------- #
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

# Zentrale Log-Senke für Container Apps (System- und Konsolen-Logs).
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# --------------------------------------------------------------------------- #
# DBaaS: Azure SQL Database (Serverless)
# --------------------------------------------------------------------------- #
resource "azurerm_mssql_server" "main" {
  name                         = "sql-${local.name_prefix}-${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = random_password.sql.result
  minimum_tls_version          = "1.2"
  tags                         = local.tags
}

resource "azurerm_mssql_database" "main" {
  name                        = "sqldb-${local.name_prefix}"
  server_id                   = azurerm_mssql_server.main.id
  sku_name                    = var.sql_sku_name
  min_capacity                = var.sql_min_capacity
  auto_pause_delay_in_minutes = var.sql_auto_pause_delay
  max_size_gb                 = var.sql_max_size_gb
  zone_redundant              = false
  storage_account_type        = "Local"
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  tags                        = local.tags
}

# IST: Zugriff aus Azure-internen Diensten (0.0.0.0 = "Allow Azure services").
# Container Apps im Consumption-Plan haben keine festen Outbound-IPs, daher ist
# dies die pragmatische Lösung. SOLL: VNet-Integration + Private Endpoint.
resource "azurerm_mssql_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# --------------------------------------------------------------------------- #
# PaaS: Azure Container Apps
# --------------------------------------------------------------------------- #
resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.name_prefix}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.tags
}

resource "azurerm_container_app" "web" {
  name                         = "ca-${local.name_prefix}-web"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.tags

  secret {
    name  = "sql-password"
    value = random_password.sql.result
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "web"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "DB_SERVER"
        value = azurerm_mssql_server.main.fully_qualified_domain_name
      }
      env {
        name  = "DB_NAME"
        value = azurerm_mssql_database.main.name
      }
      env {
        name  = "DB_USER"
        value = var.sql_admin_login
      }
      env {
        name        = "DB_PASSWORD"
        secret_name = "sql-password"
      }
      env {
        name  = "PORT"
        value = tostring(var.container_port)
      }

      # Liveness ohne DB-Abhängigkeit: Eine pausierte Serverless-DB darf nicht
      # zu einem Neustart des Containers führen.
      liveness_probe {
        transport               = "HTTP"
        port                    = var.container_port
        path                    = "/health"
        initial_delay           = 10
        interval_seconds        = 30
        failure_count_threshold = 3
      }

      readiness_probe {
        transport               = "HTTP"
        port                    = var.container_port
        path                    = "/health"
        interval_seconds        = 10
        failure_count_threshold = 3
      }
    }

    # Horizontale Skalierung anhand gleichzeitiger HTTP-Requests pro Replica.
    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = tostring(var.scale_concurrent_requests)
    }
  }

  ingress {
    external_enabled           = true
    target_port                = var.container_port
    transport                  = "auto"
    allow_insecure_connections = false

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}
