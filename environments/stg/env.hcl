locals {
  env             = "stg"
  subscription_id = "00000000-0000-0000-0000-000000000000"
  location        = "uksouth"

  # Pre-provisioned infrastructure — provided by subscription vending
  resource_group_name = "rg-stg-uksouth"
  vnet_rg             = "rg-networking-stg-uksouth"
  vnet_name           = "vnet-stg-uksouth"

  # Postgres tier for all apps in this environment
  postgres_sku        = "B_Standard_B2ms"
  postgres_storage_mb = 32768
}
