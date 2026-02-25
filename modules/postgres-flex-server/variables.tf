variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
  default = "uksouth"
}

variable "server_name" {
  type = string
}

variable "administrator_login" {
  type = string
}

variable "administrator_password" {
  type      = string
  sensitive = true
}

variable "sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "postgresql_version" {
  type    = string
  default = "16"
}

variable "storage_mb" {
  type    = number
  default = 32768
}

variable "delegated_subnet_id" {
  type        = string
  description = "Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers."
}

variable "virtual_network_id" {
  type        = string
  description = "VNet to link the private DNS zone to."
}

variable "tags" {
  type    = map(string)
  default = {"dev" = "test"}
}