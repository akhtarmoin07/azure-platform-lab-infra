variable "name" {
  description = "Virtual network name."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  type    = list(string)
  default = ["10.20.0.0/16"]
}

variable "aks_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.0.0/22"]
}

variable "private_endpoint_subnet_prefixes" {
  description = "Address prefixes reserved for Azure Private Endpoints."
  type        = list(string)
  default     = ["10.20.4.0/24"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
