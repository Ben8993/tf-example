include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  app_vars = read_terragrunt_config(find_in_parent_folders("app.hcl"))

  env = local.env_vars.locals.env
  app = local.app_vars.locals.app

  postgres_sku        = local.env_vars.locals.postgres_sku
  postgres_storage_mb = local.env_vars.locals.postgres_storage_mb
}

terraform {
  source = "../../../../modules/postgres-flex-server"
}

inputs = {
  resource_group_name = "rg-postgres-${local.app}-${local.env}-uksouth"
  server_name         = "psql-flex-${local.app}-${local.env}-uksouth"
  administrator_login = "psqladmin"

  # Set as a masked GitLab CI variable scoped to the dev environment: GITLAB_POSTGRES_ADMIN_PASSWORD
  administrator_password = get_env("${upper(local.app)}_POSTGRES_ADMIN_PASSWORD", "")

  sku_name   = local.postgres_sku
  storage_mb = local.postgres_storage_mb

  tags = {
    environment = local.env
    app         = local.app
    managed_by  = "terraform"
  }
}
