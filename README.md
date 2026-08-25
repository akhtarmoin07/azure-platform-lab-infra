# azure-platform-lab-infra

Terraform-managed Azure infrastructure for an AKS, ACR and GitOps learning platform.

## AKS capacity and upgrades

The lab runs two `Standard_B2s_v2` worker instances in the AKS system node
pool. Together they consume four regional vCPUs, which is the subscription's
current quota. The AKS Free tier removes the cluster-management charge, but the
worker VMs, disks and networking remain billable.

Node-pool upgrades use ARM settings `maxSurge = "0"` and
`maxUnavailable = "1"`. AKS therefore drains and upgrades one existing worker
at a time without requesting a third two-vCPU VM. AzureRM 4.x does not expose
`maxUnavailable`, so a narrowly scoped AzAPI resource owns the effective system
pool upgrade settings and AzureRM ignores only that nested field. This provides
scheduling capacity for the application and Gateway API lab components, but
deliberately leaves no spare regional vCPU quota. Any VM-size, node-count or
upgrade-strategy change requires a quota and cost review first.

## Managed Gateway API

Terraform installs the AKS-managed standard-channel Gateway API CRDs and
enables the sidecarless Application Routing Istio implementation. The new AKS
ingress-profile fields are managed with the AzAPI provider until the pinned
AzureRM provider exposes equivalent arguments. This creates the
`approuting-istio` GatewayClass and managed Istio control plane; Kubernetes
`Gateway` and `HTTPRoute` resources remain GitOps-managed in their respective
repositories.

## Documentation

- [Infrastructure resource catalog](docs/architecture/infrastructure-resource-catalog.md): every Terraform-managed resource, its purpose, relationships, security model and production gaps.
- [Azure SQL access automation](docs/architecture/azure-sql-access-automation.md): Entra groups, workload identities, database-role bootstrap and day-two membership model.
- [Platform scope](docs/architecture/platform-scope.md): learning goals, non-goals and success criteria.

## Azure SQL and application identity

The lab creates one private Azure SQL logical server with separate `pharmacy-dev`
and `pharmacy-prod` databases. Both databases use the low-cost `Basic` SKU, local
backup redundancy and a seven-day short-term retention policy. Public SQL network
access is disabled; AKS resolves and reaches the server through an Azure Private
Endpoint and the `privatelink.database.windows.net` private DNS zone.

The dedicated `id-azplab-sql-bootstrap` workload identity is the Azure SQL Entra
administrator. A protected pipeline uses it temporarily inside AKS to reconcile
contained group/identity users and least-privilege database roles. No SQL
administrator password is created. Separate runtime and migration identities are
federated with these Kubernetes ServiceAccounts:

- `system:serviceaccount:dev:pharmacy-backend`
- `system:serviceaccount:prod:pharmacy-backend`
- `system:serviceaccount:dev:pharmacy-migration`
- `system:serviceaccount:prod:pharmacy-migration`

Terraform grants both identities permission to read secrets from Key Vault. It
does not place a database password in Key Vault because workload identity provides
passwordless database authentication and Terraform-managed secret values would be
recorded in state. Key Vault public network access is disabled and AKS reaches it
through a separate private endpoint and private DNS zone.

The AKS Key Vault add-on identity deliberately has no vault-wide secret-reader
role. Secret access is granted to workload identities individually.

Terraform also creates dev-developer, prod-reader and prod-admin Entra groups but
intentionally does not manage their human membership. After provisioning, the
protected SQL access workflow creates/reconciles their database users and roles.
Schema migrations remain an application delivery responsibility and use the
separate migration identities.

### Required GitHub environment variable

Set `PLATFORM_ADMIN_GROUP_DISPLAY_NAME` in the `lab` GitHub environment to the
exact display name of the group whose object ID is already stored in
`PLATFORM_ADMIN_GROUP_OBJECT_ID`.
