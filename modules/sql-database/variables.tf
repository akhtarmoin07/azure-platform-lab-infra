variable "server_name" {
  description = "Globally unique Azure SQL logical server name."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "entra_admin_login_username" {
  description = "Display name used for the Microsoft Entra administrator."
  type        = string
}

variable "entra_admin_object_id" {
  description = "Object ID of the Microsoft Entra administrators group."
  type        = string
}

variable "database_names" {
  description = "Databases created on the logical server."
  type        = set(string)
}

variable "database_sku_name" {
  description = "Azure SQL Database SKU used by the short-lived lab."
  type        = string
  default     = "Basic"
}

variable "database_max_size_gb" {
  type    = number
  default = 2
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "virtual_network_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
