variable "subscription_id" {
  description = "Azure subscription used by the lab."
  type        = string
}

variable "platform_admin_group_object_id" {
  description = "Microsoft Entra object ID of the platform administrators security group."
  type        = string
}

variable "location" {
  type    = string
  default = "swedencentral"
}

variable "project_name" {
  type    = string
  default = "azplab"
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.20.0.0/16"]
}

variable "aks_subnet_prefixes" {
  type    = list(string)
  default = ["10.20.0.0/22"]
}

variable "aks_service_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "aks_dns_service_ip" {
  type    = string
  default = "10.30.0.10"
}

variable "aks_pod_cidr" {
  type    = string
  default = "10.40.0.0/16"
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

variable "acr_sku" {
  type    = string
  default = "Basic"
}

variable "adls_containers" {
  type    = set(string)
  default = ["raw", "curated", "models"]
}

variable "log_retention_in_days" {
  type    = number
  default = 30
}

variable "enable_container_insights" {
  description = "Enables paid Azure Container Insights ingestion."
  type        = bool
  default     = false
}

variable "enable_azure_policy" {
  type    = bool
  default = false
}

variable "monthly_budget_amount" {
  type    = number
  default = 100
}

variable "budget_start_date" {
  description = "First day of the budget month in RFC3339 format."
  type        = string
  default     = "2026-08-01T00:00:00Z"
}

variable "budget_contact_emails" {
  type      = list(string)
  sensitive = true

  validation {
    condition     = length(var.budget_contact_emails) > 0
    error_message = "At least one budget contact email is required."
  }
}

variable "tags" {
  type = map(string)
  default = {
    environment = "lab"
    managed-by  = "terraform"
    project     = "azure-platform-lab"
  }
}
