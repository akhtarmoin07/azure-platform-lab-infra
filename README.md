# azure-platform-lab-infra

Terraform-managed Azure infrastructure for an AKS, ACR and GitOps learning platform.

## Documentation

- [Infrastructure resource catalog](docs/architecture/infrastructure-resource-catalog.md): every Terraform-managed resource, its purpose, relationships, security model and production gaps.
- [Platform scope](docs/architecture/platform-scope.md): learning goals, non-goals and success criteria.

## Azure SQL and application identity

The lab creates one private Azure SQL logical server with separate `pharmacy-dev`
and `pharmacy-prod` databases. Both databases use the low-cost `Basic` SKU, local
backup redundancy and a seven-day short-term retention policy. Public SQL network
access is disabled; AKS resolves and reaches the server through an Azure Private
Endpoint and the `privatelink.database.windows.net` private DNS zone.

The Microsoft Entra platform administrator group is the server administrator.
No SQL administrator password is created. Separate user-assigned identities are
federated with these Kubernetes ServiceAccounts:

- `system:serviceaccount:dev:pharmacy-backend`
- `system:serviceaccount:prod:pharmacy-backend`

Terraform grants both identities permission to read secrets from Key Vault. It
does not place a database password in Key Vault because workload identity provides
passwordless database authentication and Terraform-managed secret values would be
recorded in state. Key Vault public network access is disabled and AKS reaches it
through a separate private endpoint and private DNS zone.

The AKS Key Vault add-on identity deliberately has no vault-wide secret-reader
role. Secret access is granted to workload identities individually.

After provisioning, a controlled database bootstrap must create a contained user
for each managed identity and grant only the required database permissions. Schema
migrations remain an application delivery responsibility rather than a Terraform
resource.

### Required GitHub environment variable

Set `PLATFORM_ADMIN_GROUP_DISPLAY_NAME` in the `lab` GitHub environment to the
exact display name of the group whose object ID is already stored in
`PLATFORM_ADMIN_GROUP_OBJECT_ID`.
