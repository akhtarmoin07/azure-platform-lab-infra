# Azure Data and AI Platform Lab

## Purpose

Build a cost-controlled, production-pattern Azure platform that demonstrates
the responsibilities of a Platform Engineer supporting Data and AI teams.

## Primary learning goals

- Provision Azure infrastructure using reusable Terraform modules.
- Operate containerized workloads on Azure Kubernetes Service.
- Package Kubernetes applications with Helm.
- Implement continuous delivery using GitOps and Argo CD.
- Apply identity, networking, secrets-management and workload-security controls.
- Implement monitoring, alerting, operational runbooks and troubleshooting.
- Design reliable, resilient and maintainable platform components.
- Provide reusable automation and self-service application onboarding.

## Secondary learning goals

- Provision and configure an Azure Databricks environment.
- Understand how Data and AI workloads consume platform capabilities.
- Run a small synthetic data workload for operational exercises.
- Monitor and troubleshoot basic Databricks platform behavior.

## Non-goals

- Reproducing Redcare Pharmacy's proprietary architecture.
- Processing real pharmacy, patient or customer data.
- Developing advanced machine-learning models.
- Claiming production availability from a single-node learning cluster.
- Running expensive Azure services continuously.

## Platform users

- Platform engineers provision and operate shared infrastructure.
- Application engineers build and deploy containerized services.
- Data and AI engineers consume Databricks, storage and Kubernetes capabilities.
- Security engineers define and review identity and workload controls.

## Success criteria

- Azure infrastructure can be created and destroyed reproducibly.
- Terraform state is remote, protected and separated from application delivery.
- No permanent Azure credentials are stored in GitHub.
- AKS hosts isolated development and production-pattern namespaces.
- Applications are packaged with Helm and reconciled through GitOps.
- Changes pass automated validation before deployment.
- Platform health can be observed through metrics, logs and alerts.
- Common failures have documented troubleshooting runbooks.
- Monthly out-of-pocket Azure spending remains below EUR 50.
