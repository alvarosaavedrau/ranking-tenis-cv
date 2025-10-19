# Grupo de recursos principal
resource "azurerm_resource_group" "main" {
  name     = "${local.prefix_esp}-rg"
  location = local.az_location_esp
  tags     = local.tags
}

# Container Registry (Basic tier - más económico)
resource "azurerm_container_registry" "main" {
  name                = "${local.az_location_abbreviation_esp}${local.project}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = local.tags
}

# Log Analytics Workspace para Application Insights
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.prefix_esp}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${local.prefix_esp}-ai"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.tags
}

# PostgreSQL Flexible Server (configuración más económica)
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${local.prefix_esp}-psql"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "15"
  delegated_subnet_id    = azurerm_subnet.database.id
  private_dns_zone_id    = azurerm_private_dns_zone.main.id
  administrator_login    = var.admin_username
  administrator_password = var.admin_password
  zone                   = "1"

  storage_mb = 32768  # 32 GB - mínimo
  
  sku_name   = "B_Standard_B1ms"  # 1 vCore, 2 GB RAM - más económico

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = local.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.main]
}

# Base de datos para la aplicación
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "tenis_results"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Virtual Network para Container Apps y PostgreSQL
resource "azurerm_virtual_network" "main" {
  name                = "${local.prefix_esp}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

# Subnet para Container Apps
resource "azurerm_subnet" "container_apps" {
  name                 = "container-apps-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "Microsoft.App.environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Subnet para PostgreSQL
resource "azurerm_subnet" "database" {
  name                 = "database-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# DNS Zone privada para PostgreSQL
resource "azurerm_private_dns_zone" "main" {
  name                = "${local.prefix_esp}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

# Link de la DNS Zone privada con la Virtual Network
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = "${local.prefix_esp}-pdz-link"
  private_dns_zone_name = azurerm_private_dns_zone.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
  resource_group_name   = azurerm_resource_group.main.name
  tags                  = local.tags
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "${local.prefix_esp}-cae"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id   = azurerm_subnet.container_apps.id
  tags                       = local.tags
}

# Container App para la aplicación web
resource "azurerm_container_app" "web" {
  name                         = "${local.prefix_esp}-web"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.tags

  template {
    container {
      name   = "tenis-web"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"  # Imagen temporal
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "DATABASE_URL"
        value = "postgresql://${var.admin_username}:${var.admin_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.main.name}?sslmode=require"
      }

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.main.connection_string
      }
    }

    min_replicas = 0  # Escalado a 0 para ahorrar costos
    max_replicas = 2
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Configuración para escalar a 0 cuando no hay tráfico
  dapr {
    app_id       = "tenis-web"
    app_port     = 80
    app_protocol = "http"
  }
}