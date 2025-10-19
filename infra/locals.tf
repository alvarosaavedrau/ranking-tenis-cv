locals {
  az_location_esp              = "spaincentral"
  az_location_ams              = "westeurope"
  az_location_abbreviation_esp = "esp"
  az_location_abbreviation_ams = "ams"
  project                      = "ranking"
  prefix_esp                   = "${local.az_location_abbreviation_esp}-${local.project}"
  prefix_ams                   = "${local.az_location_abbreviation_ams}-${local.project}"

  tags = {
    Proyecto   = upper(local.project)
    Deployment = "Terraform"
  }
}
