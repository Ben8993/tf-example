include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.env
}

terraform {
  source = "../../../modules/postgres-flex-server"
}

inputs = {
  resource_group_name = "rg-postgres-${local.env}-uksouth"
  server_name         = "psql-flex-${local.env}-uksouth"
  administrator_login = "psqladmin"

  # Set as a masked GitLab CI variable: POSTGRES_ADMIN_PASSWORD (scoped to dev environment)
  administrator_password = get_env("POSTGRES_ADMIN_PASSWORD", "")

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  tags = {
    environment = local.env
    managed_by  = "terraform"
  }
}
