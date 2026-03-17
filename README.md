# tf-example — Azure PostgreSQL Flexible Server

Terraform module and Terragrunt environment configs for deploying an Azure Database for PostgreSQL Flexible Server per app, with GitLab CI/CD for automated deployments.

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
    ├── dev/
    │   ├── env.hcl                 # Dev subscription, region, postgres tier
    │   └── gitlab/
    │       ├── app.hcl             # App name — drives all resource naming
    │       └── postgres-flex/
    │           └── terragrunt.hcl  # Calls module; reads env.hcl + app.hcl
    ├── stg/
    │   ├── env.hcl
    │   └── gitlab/
    │       ├── app.hcl
    │       └── postgres-flex/
    │           └── terragrunt.hcl
    └── prod/
        ├── env.hcl
        └── gitlab/
            ├── app.hcl
            └── postgres-flex/
                └── terragrunt.hcl
```

Adding a second app is just adding a sibling directory with its own `app.hcl`:

```
environments/dev/
├── gitlab/
│   ├── app.hcl             # app = "gitlab"
│   └── postgres-flex/
│       └── terragrunt.hcl
└── another-app/
    ├── app.hcl             # app = "another-app"
    └── postgres-flex/
        └── terragrunt.hcl  # identical content — no changes needed elsewhere
```

`run-all` at the environment root picks up all app directories automatically.

## Configuration

### 1. Update env.hcl for each environment

Each `env.hcl` is the single source of truth for that environment — subscription identity, pre-provisioned networking, and the postgres SKU tier for all apps in that environment:

```hcl
locals {
  env             = "dev"           # dev | stg | prod
  subscription_id = "00000000-0000-0000-0000-000000000000"
  location        = "uksouth"

  # Pre-provisioned infrastructure — provided by subscription vending
  resource_group_name = "rg-dev-uksouth"
  vnet_rg             = "rg-networking-dev-uksouth"
  vnet_name           = "vnet-dev-uksouth"

  # Postgres tier for all apps in this environment
  postgres_sku        = "B_Standard_B1ms"
  postgres_storage_mb = 32768
}
```

### 2. Add an app.hcl for each app

`app.hcl` lives at the app directory root and defines the app name. All resource names are constructed from `env` + `app`:

```hcl
locals {
  app = "gitlab"
}
```

| Resource | Naming pattern | Example (gitlab, dev) |
|---|---|---|
| Resource group | `rg-postgres-{app}-{env}-uksouth` | `rg-postgres-gitlab-dev-uksouth` |
| Postgres server | `psql-flex-{app}-{env}-uksouth` | `psql-flex-gitlab-dev-uksouth` |

The `postgres-flex/terragrunt.hcl` inside each app reads both `env.hcl` and `app.hcl` via `find_in_parent_folders()` — no hardcoded values.

### 3. GitLab CI/CD variables

Set the following as masked variables in **Settings → CI/CD → Variables**:

| Variable | Description |
|---|---|
| `ARM_CLIENT_ID` | Service Principal app ID |
| `ARM_CLIENT_SECRET` | Service Principal secret |
| `ARM_TENANT_ID` | Azure AD tenant ID |
| `{APP}_POSTGRES_ADMIN_PASSWORD` | DB admin password per app (e.g. `GITLAB_POSTGRES_ADMIN_PASSWORD`) |
| `ARTIFACTORY_HOSTNAME` | Artifactory hostname (e.g. `artifactory.yourcompany.com`) |
| `ARTIFACTORY_REPO` | Artifactory Terraform provider repo name |
| `ARTIFACTORY_TOKEN` | Artifactory identity token |

`CI_JOB_TOKEN` and `CI_PROJECT_ID` are injected automatically by GitLab.

All provider downloads are routed through the Artifactory network mirror via a dynamically generated `.terraformrc` — no changes needed to individual module `versions.tf` files.

#### Environment-scoped variables

`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, and `ARM_TENANT_ID` will differ per environment in real use (separate Service Principals per subscription). GitLab supports scoping variables to a specific environment so the same variable name resolves to a different value depending on which environment the job is running in.

The pipeline jobs already declare `environment: name: dev`, `environment: name: stg`, and `environment: name: prod` in their templates, so GitLab knows which environment each job belongs to.

To configure scoped variables:
1. Go to **Settings → CI/CD → Variables**
2. Add the variable (e.g. `ARM_CLIENT_ID`) with the prod value and set **Environment scope** to `prod`
3. Repeat for each environment with the appropriate value and scope

GitLab will automatically inject the correct value based on the job's environment. No pipeline changes required.

## Resource groups

The module creates a dedicated resource group per app per environment — it does not deploy into the pre-provisioned landing zone RG. This follows standard Azure landing zone practice: platform vending owns the networking RG, application teams own their workload RGs.

| App | Environment | Resource group created by Terraform |
|---|---|---|
| gitlab | dev | `rg-postgres-gitlab-dev-uksouth` |
| gitlab | stg | `rg-postgres-gitlab-stg-uksouth` |
| gitlab | prod | `rg-postgres-gitlab-prod-uksouth` |

The pre-provisioned `resource_group_name` in `env.hcl` remains available for reference (e.g. VNet lookups by other modules) but is not used by the postgres module.

## Environments

| Environment | Postgres SKU | Storage |
|---|---|---|
| `dev` | `B_Standard_B1ms` | 32 GB |
| `stg` | `B_Standard_B2ms` | 32 GB |
| `prod` | `GP_Standard_D2s_v3` | 64 GB |

SKU and storage are set once in `env.hcl` and apply to all apps in that environment.

## Pipeline behaviour

| Trigger | dev | stg | prod |
|---|---|---|---|
| Every pipeline | validate + plan | validate + plan | validate + plan |
| Merge to default branch | manual apply | manual apply | manual apply |
| `CONFIRM_DESTROY=true` | plan-destroy, then manual destroy | plan-destroy, then manual destroy | plan-destroy, then manual destroy |

## Adding a new app

1. Create `environments/{env}/{app}/app.hcl` with `app = "{app-name}"` in all three environments
2. Copy `postgres-flex/terragrunt.hcl` from an existing app — the content is identical across apps
3. Add a `{APP}_POSTGRES_ADMIN_PASSWORD` CI variable scoped per environment

No pipeline changes needed. `run-all` picks up the new directory automatically.

## Adding a new module

Follow this pattern to add any new Azure resource alongside the existing postgres module.

**1. Create the Terraform module**

```
modules/
└── your-module/
    ├── main.tf       # resource definitions
    ├── variables.tf  # declare all inputs; no provider block
    ├── outputs.tf
    └── versions.tf   # required_providers only — provider block is generated by Terragrunt
```

`versions.tf` should only contain `required_providers`. The `provider {}` block is injected automatically by the root `terragrunt.hcl`:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}
```

**2. Add a Terragrunt config per app per environment**

```
environments/dev/gitlab/your-module/terragrunt.hcl
environments/stg/gitlab/your-module/terragrunt.hcl
environments/prod/gitlab/your-module/terragrunt.hcl
```

Each `terragrunt.hcl` reads `env.hcl` and `app.hcl`:

```hcl
include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  app_vars = read_terragrunt_config(find_in_parent_folders("app.hcl"))
  env      = local.env_vars.locals.env
  app      = local.app_vars.locals.app
}

terraform {
  source = "../../../../modules/your-module"
}

inputs = {
  resource_group_name = "rg-${local.app}-${local.env}-uksouth"
  tags = {
    environment = local.env
    app         = local.app
    managed_by  = "terraform"
  }
}
```

`location` and `env` are passed automatically from the root config.

**3. No CI changes needed**

The pipeline uses `terragrunt run-all` at the environment root (`/dev`, `/stg`, `/prod`). Any subdirectory with a `terragrunt.hcl` is picked up automatically.

## Running locally

```bash
# Plan all apps in dev
cd environments/dev
terragrunt run-all plan

# Plan a single app
cd environments/dev/gitlab/postgres-flex
terragrunt plan
```

Ensure `ARM_*` and `{APP}_POSTGRES_ADMIN_PASSWORD` environment variables are exported in your shell before running.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= 0.67
- An Azure Service Principal with Contributor access to the target subscriptions
