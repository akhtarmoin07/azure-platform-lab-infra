variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "containers" {
  type    = set(string)
  default = ["raw", "curated", "models"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
