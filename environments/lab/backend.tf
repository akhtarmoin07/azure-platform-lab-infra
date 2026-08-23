terraform {
  backend "azurerm" {
    resource_group_name  = "state-file-storage"
    storage_account_name = "tfmoinstorage"
    container_name       = "tfstate"
    key                  = "lab.tfstate"
    use_azuread_auth     = true
  }
}
