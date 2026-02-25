include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/postgres-flex-server"
}

inputs = {
  resource_group_name = "rg-postgres-prod-uksouth"
  server_name         = "psql-flex-prod-uksouth"
  administrator_login = "psqladmin"

  # Set as a masked GitLab CI variable: POSTGRES_ADMIN_PASSWORD_PROD
  administrator_password = get_env("POSTGRES_ADMIN_PASSWORD_PROD", "")

  sku_name   = "GP_Standard_D2s_v3"
  storage_mb = 65536

  # Replace with your actual subnet and VNet resource IDs.
  # The subnet must be delegated to Microsoft.DBforPostgreSQL/flexibleServers.
  delegated_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-networking-prod/providers/Microsoft.Network/virtualNetworks/vnet-prod-uksouth/subnets/snet-postgres-prod"
  virtual_network_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-networking-prod/providers/Microsoft.Network/virtualNetworks/vnet-prod-uksouth"

  tags = {
    environment = "prod"
    managed_by  = "terraform"
  }
}