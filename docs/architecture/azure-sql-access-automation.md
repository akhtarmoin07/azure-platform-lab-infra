# Azure SQL access automation

## Objective

The platform provisions database access without SQL passwords, person-specific
database users, or recurring terminal commands. Infrastructure, database access,
schema migration, and application runtime use separate identities.

## Terraform resources

| Resource | Purpose |
|---|---|
| Three `azuread_group_without_members` resources | Create stable dev-developer, prod-reader, and prod-admin security groups while deliberately leaving human membership to Entra governance. |
| `id-azplab-sql-bootstrap` | Azure SQL Entra administrator and temporary AKS bootstrap workload identity. |
| `id-azplab-migration-dev/prod` | Separate schema-change identities for each database. |
| Federated identity credentials | Bind each managed identity to one exact Kubernetes namespace and ServiceAccount subject. |
| ACR `AcrPush` assignment | Allows the protected automation identity to publish the immutable bootstrap image. |
| AKS Cluster User/RBAC Admin assignments | Allow the protected workflow identity to create and observe the temporary bootstrap Job. |

The existing backend identities remain runtime-only. Azure RBAC assignments do
not grant Azure SQL data permissions; the database bootstrap creates those
contained principals and role memberships inside each database.

## Why group membership is outside Terraform

The `azuread_group_without_members` resource manages the lifecycle and stable
object ID of each group but intentionally does not reconcile members. This
prevents employee object IDs from entering Terraform state and avoids requiring
an infrastructure deployment for onboarding or offboarding. Group owners, PIM,
access packages, and access reviews are the appropriate day-two control plane.

## One-time tenant prerequisite

The GitHub OIDC application's service principal needs the Microsoft Graph
application permission `Group.ReadWrite.All`, followed by tenant administrator
consent. This permits Terraform to create and maintain the three group objects.
It does not make Terraform the membership system of record.

No `Directory.ReadWrite.All` permission is required. The narrower group-specific
permission should be used.

## Deployment sequence

1. Merge and sync the GitOps `platform-system` namespace and network policy.
2. Grant/admin-consent `Group.ReadWrite.All` to the existing GitHub OIDC app.
3. Run Terraform Plan and review the SQL administrator, identities, federation,
   groups, and role assignments.
4. Run the protected Terraform Apply workflow.
5. Run `Bootstrap Azure SQL access` with the protected `lab` environment.
6. Add engineers to the appropriate Entra group through the approved identity
   governance process.
7. Promote migration identity client IDs and immutable application image digests
   into GitOps through a reviewed pull request.

The SQL bootstrap reconciler uses `CREATE USER ... WITH SID ..., TYPE = E/X`.
Binding directly to the managed-identity client ID or group object ID avoids an
Azure SQL Microsoft Graph lookup and therefore avoids granting Directory Readers
to the SQL logical server identity.
