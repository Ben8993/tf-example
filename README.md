# tf-example — Azure PostgreSQL Flexible Server

Terraform module and Terragrunt environment configs for deploying an Azure Database for PostgreSQL Flexible Server into an existing Azure subscription, with GitLab CI/CD for automated deployments.

## Structure

```
tf-example/
├── .gitlab-ci.yml
├── modules/
│   └── postgres-flex-server/       # Reusable Terraform module
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
└── environments/
    ├── terragrunt.hcl              # Root config: provider, GitLab HTTP backend
    ├── prod/
    │   ├── env.hcl                 # Prod subscription, region, networking values
    │   └── postgres-flex/
    │       └── terragrunt.hcl      # Calls module with prod inputs
    └── non-prod/
        ├── env.hcl                 # Non-prod subscription, region, networking values
        └── postgres-flex/
            └── terragrunt.hcl      # Calls module with non-prod inputs
```

## Configuration

### 1. Update env.hcl for each environment

Each `env.hcl` is the single source of truth for that environment. Update the values to match your Azure setup:

```hcl
locals {
  env             = "prod"
  subscription_id = "00000000-0000-0000-0000-000000000000"  # your subscription ID
  location        = "uksouth"
}
```

In real use, `prod` and `non-prod` will each have their own subscription ID.

### 2. GitLab CI/CD variables

Set the following as masked variables in **Settings → CI/CD → Variables**:

| Variable | Description |
|---|---|
| `ARM_CLIENT_ID` | Service Principal app ID |
| `ARM_CLIENT_SECRET` | Service Principal secret |
| `ARM_TENANT_ID` | Azure AD tenant ID |
| `POSTGRES_ADMIN_PASSWORD_PROD` | Prod server admin password |
| `POSTGRES_ADMIN_PASSWORD_NONPROD` | Non-prod server admin password |
| `ARTIFACTORY_HOSTNAME` | Artifactory hostname (e.g. `artifactory.yourcompany.com`) |
| `ARTIFACTORY_REPO` | Artifactory Terraform provider repo name |
| `ARTIFACTORY_TOKEN` | Artifactory identity token |

`CI_JOB_TOKEN` and `CI_PROJECT_ID` are injected automatically by GitLab.

All provider downloads are routed through the Artifactory network mirror via a dynamically generated `.terraformrc` — no changes needed to individual module `versions.tf` files.

## Environments

| Environment | SKU | Storage | HA |
|---|---|---|---|
| `prod` | `GP_Standard_D2s_v3` | 64 GB | No |
| `non-prod` | `B_Standard_B1ms` | 32 GB | No |

## Pipeline behaviour

| Trigger | non-prod | prod |
|---|---|---|
| Every pipeline | validate + plan | validate + plan |
| Merge to default branch | manual apply | manual apply |

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

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= 0.67
- An Azure Service Principal with Contributor access to the target resource groups