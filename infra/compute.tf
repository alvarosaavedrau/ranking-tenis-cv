resource "azurerm_service_plan" "function_app" {
  name                = "${local.prefix_esp}func-plan"
  location            = local.az_location_ams
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "FC1"
}

resource "azurerm_function_app_flex_consumption" "function_app" {
  name                = "${local.prefix_esp}func-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.az_location_ams
  service_plan_id     = azurerm_service_plan.function_app.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.function_storage.primary_blob_endpoint}${azurerm_storage_container.function_storage.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.function_storage.primary_access_key
  runtime_name                = "python"
  runtime_version             = "3.12"
  maximum_instance_count      = 50
  instance_memory_in_mb       = 512

  site_config {}

  app_settings = {
    "COSMOS_DB_ENDPOINT"       = azurerm_cosmosdb_account.db.endpoint
    "COSMOS_DB_KEY"            = azurerm_cosmosdb_account.db.primary_key
    "COSMOS_DB_DATABASE_NAME"  = azurerm_cosmosdb_sql_database.tenis_db.name
    "COSMOS_DB_CONTAINER_NAME" = azurerm_cosmosdb_sql_container.partidos.name
  }
}

resource "azurerm_static_web_app" "frontend" {
  name                = "${local.prefix_esp}static-web-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.az_location_ams
  sku_tier            = "Free"
  sku_size            = "Free"
}
