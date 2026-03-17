locals {
  env             = "prod"
  subscription_id = "00000000-0000-0000-0000-000000000000"
  location        = "uksouth"

  # Pre-provisioned infrastructure — provided by subscription vending
  resource_group_name = "rg-prod-uksouth"
  vnet_rg             = "rg-networking-prod-uksouth"
  vnet_name           = "vnet-prod-uksouth"

  # Postgres tier for all apps in this environment
  postgres_sku        = "GP_Standard_D2s_v3"
  postgres_storage_mb = 65536
}