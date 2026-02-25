include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/postgres-flex-server"
}

inputs = {
  resource_group_name = "rg-postgres-non-prod-uksouth"
  server_name         = "psql-flex-non-prod-uksouth"
  administrator_login = "psqladmin"

  # Set as a masked GitLab CI variable: POSTGRES_ADMIN_PASSWORD_NONPROD
  administrator_password = get_env("POSTGRES_ADMIN_PASSWORD_NONPROD", "")

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  # Replace with your actual subnet and VNet resource IDs.
  # The subnet must be delegated to Microsoft.DBforPostgreSQL/flexibleServers.
  delegated_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-networking-nonprod/providers/Microsoft.Network/virtualNetworks/vnet-nonprod-uksouth/subnets/snet-postgres-nonprod"
  virtual_network_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-networking-nonprod/providers/Microsoft.Network/virtualNetworks/vnet-nonprod-uksouth"

  tags = {
    environment = "non-prod"
    managed_by  = "terraform"
  }
}