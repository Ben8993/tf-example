include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  subscription_id = local.env_vars.locals.subscription_id
  env             = local.env_vars.locals.env
  vnet_rg         = local.env_vars.locals.vnet_rg
  vnet_name       = local.env_vars.locals.vnet_name
  subnet_name     = local.env_vars.locals.subnet_name

  vnet_base = "/subscriptions/${local.subscription_id}/resourceGroups/${local.vnet_rg}/providers/Microsoft.Network/virtualNetworks/${local.vnet_name}"
}

terraform {
  source = "../../../modules/postgres-flex-server"
}

inputs = {
  resource_group_name = "rg-postgres-${local.env}-uksouth"
  server_name         = "psql-flex-${local.env}-uksouth"
  administrator_login = "psqladmin"

  # Set as a masked GitLab CI variable: POSTGRES_ADMIN_PASSWORD_NONPROD
  administrator_password = get_env("POSTGRES_ADMIN_PASSWORD_NONPROD", "")

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  delegated_subnet_id = "${local.vnet_base}/subnets/${local.subnet_name}"
  virtual_network_id  = local.vnet_base

  tags = {
    environment = local.env
    managed_by  = "terraform"
  }
}