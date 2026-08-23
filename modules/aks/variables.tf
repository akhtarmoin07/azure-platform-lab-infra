variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "dns_prefix" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "control_plane_identity_id" {
  type = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant used for AKS authentication and Azure RBAC."
  type        = string
}

variable "node_vm_size" {
  type    = string
  default = "Standard_B2s_v2"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "node_os_disk_size_gb" {
  type    = number
  default = 30
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "service_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "10.30.0.10"
}

variable "pod_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "log_analytics_workspace_id" {
  type    = string
  default = null
}

variable "enable_container_insights" {
  type    = bool
  default = false
}

variable "enable_azure_policy" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
