resource "azurerm_resource_group" "main" {
  name     = "${local.prefix_esp}-rg"
  location = local.az_location_esp

  tags = merge(local.tags, {
    Creado = "19/10/2025"
  })
}