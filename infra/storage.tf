resource "azurerm_storage_account" "function_storage" {
  name                     = replace("${local.prefix_esp}storageranking", "-", "")
  resource_group_name      = azurerm_resource_group.main.name
  location                 = local.az_location_esp
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "function_storage" {
  name                  = "function-container"
  storage_account_id    = azurerm_storage_account.function_storage.id
  container_access_type = "private"
}

resource "azurerm_cosmosdb_account" "db" {
  name                = "${local.prefix_esp}cosmosdb"
  location            = local.az_location_esp
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  free_tier_enabled   = true

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = local.az_location_esp
    failover_priority = 0
  }

  capabilities {
    name = "EnableServerless"
  }
}

resource "azurerm_cosmosdb_sql_database" "tenis_db" {
  name                = "tenisdb"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.db.name
}

resource "azurerm_cosmosdb_sql_container" "partidos" {
  name                = "partidos"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.db.name
  database_name       = azurerm_cosmosdb_sql_database.tenis_db.name
  partition_key_paths = ["/id"]

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }
}