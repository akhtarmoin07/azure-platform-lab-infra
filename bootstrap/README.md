# Terraform backend bootstrap

The backend was created manually before Terraform:

- Resource group: `state-file-storage`
- Storage account: `tfmoinstorage`
- Private container: `tfstate`

The signed-in Terraform operator requires the `Storage Blob Data Contributor`
role on the storage account. The committed lab `backend.tf` uses Microsoft
Entra ID authentication and stores the platform state as `lab.tfstate`.
