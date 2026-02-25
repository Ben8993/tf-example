# tf-example — Azure PostgreSQL Flexible Server

Terraform module and Terragrunt environment configs for deploying an Azure Database for PostgreSQL Flexible Server into an existing Azure subscription, with GitLab CI/CD for automated deployments.

## Structure

```
tf-example/
├── modules/
│   └── postgres-flex-server/   # Reusable Terraform module
└── environments/
    ├── terragrunt.hcl          # Root config: provider, GitLab HTTP backend
    ├── prod/
    │   ├── env.hcl
    │   └── postgres-flex/terragrunt.hcl
    └── non-prod/
        ├── env.hcl
        └── postgres-flex/terragrunt.hcl
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= 0.67
- An existing Azure subscription with a VNet and a subnet delegated to `Microsoft.DBforPostgreSQL/flexibleServers`
- An Azure Service Principal with Contributor access to the target resource group

## Configuration

### 1. Update the subscription ID

In `environments/terragrunt.hcl`, replace the placeholder:

```hcl
subscription_id = "00000000-0000-0000-0000-000000000000"
```

### 2. Update subnet and VNet IDs

In each environment's `terragrunt.hcl`, replace the `delegated_subnet_id` and `virtual_network_id` with your actual resource IDs.

### 3. GitLab CI/CD variables

Set the following as masked variables in **Settings → CI/CD → Variables**:

| Variable | Description |
|---|---|
| `ARM_CLIENT_ID` | Service Principal app ID |
| `ARM_CLIENT_SECRET` | Service Principal secret |
| `ARM_TENANT_ID` | Azure AD tenant ID |
| `ARM_SUBSCRIPTION_ID` | Target subscription ID |
| `POSTGRES_ADMIN_PASSWORD_PROD` | Prod server admin password |
| `POSTGRES_ADMIN_PASSWORD_NONPROD` | Non-prod server admin password |

## Environments

| Environment | SKU | Storage | HA |
|---|---|---|---|
| `prod` | `GP_Standard_D2s_v3` | 64 GB | No |
| `non-prod` | `B_Standard_B1ms` | 32 GB | No |

## Pipeline behaviour

| Trigger | non-prod | prod |
|---|---|---|
| Merge request | validate + plan | validate + plan |
| Merge to default branch | auto apply | manual apply |

## Running locally

```bash
# Plan non-prod
cd environments/non-prod/postgres-flex
terragrunt plan

# Plan prod
cd environments/prod/postgres-flex
terragrunt plan
```

Ensure `ARM_*` environment variables are exported in your shell before running.