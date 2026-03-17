# Pipeline Flow & How to Extend

## Pipeline Flow

Every pipeline runs the same five stages in order. Not all stages produce jobs on every run — the rules that control this are described below.

```
validate → plan → apply → plan-destroy → destroy
```

### Stage behaviour at a glance

| Stage | When it runs | Trigger |
|---|---|---|
| `validate` | Every pipeline | Automatic |
| `plan` | Every pipeline | Automatic (after validate) |
| `apply` | Default branch only | **Manual** |
| `plan-destroy` | Default branch + `CONFIRM_DESTROY=true` | Automatic |
| `destroy` | Default branch + `CONFIRM_DESTROY=true` | **Manual** (after plan-destroy) |

Each stage runs jobs for all three environments (`dev`, `stg`, `prod`) in parallel. Apply and destroy are always manual — there is no automatic promotion.

### Normal development flow

```
feature branch push
  └── validate → plan          (shows what would change, no lock acquired)

merge to main
  └── validate → plan → [apply:dev ▶] [apply:stg ▶] [apply:prod ▶]
                                 ↑ each must be clicked manually in GitLab
```

### Destroy flow

Triggered by running a pipeline on `main` with the variable `CONFIRM_DESTROY=true` set.

```
CONFIRM_DESTROY=true pipeline on main
  └── validate → plan → plan-destroy   (automatic — shows what will be removed)
                              └── [destroy:dev ▶] [destroy:stg ▶] [destroy:prod ▶]
                                         ↑ manual, only visible after plan-destroy passes
```

---

## How `run-all` keeps the CI zero-touch

The CI never targets individual modules. Each job does:

```sh
cd "${ENV_DIR}"          # e.g. environments/dev
terragrunt run-all plan
```

Terragrunt walks the directory tree from `ENV_DIR`, finds every `terragrunt.hcl`, and runs the command against all of them in dependency order. **Adding a new app or module requires no changes to `.gitlab-ci.yml`.**

---

## Adding a New App

An "app" is a top-level directory inside each environment that groups all the Terraform modules for that application.

### 1. Create the app directory and `app.hcl` in each environment

```
environments/
├── dev/
│   └── <app-name>/
│       └── app.hcl          ← create this
├── stg/
│   └── <app-name>/
│       └── app.hcl          ← create this
└── prod/
    └── <app-name>/
        └── app.hcl          ← create this
```

`app.hcl` contains a single local — the app name, which drives all resource naming downstream:

```hcl
locals {
  app = "<app-name>"
}
```

### 2. Add a module directory under the app

For each Terraform module this app needs, create a subdirectory with a `terragrunt.hcl`:

```
environments/dev/<app-name>/
└── postgres-flex/
    └── terragrunt.hcl
```

The `terragrunt.hcl` reads both `env.hcl` and `app.hcl` from parent folders — no hardcoded values:

```hcl
include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  app_vars = read_terragrunt_config(find_in_parent_folders("app.hcl"))

  env = local.env_vars.locals.env
  app = local.app_vars.locals.app
}

terraform {
  source = "../../../../modules/postgres-flex-server"
}

inputs = {
  resource_group_name    = "rg-postgres-${local.app}-${local.env}-uksouth"
  server_name            = "psql-flex-${local.app}-${local.env}-uksouth"
  administrator_login    = "psqladmin"
  administrator_password = get_env("${upper(local.app)}_POSTGRES_ADMIN_PASSWORD", "")
  sku_name               = local.env_vars.locals.postgres_sku
  storage_mb             = local.env_vars.locals.postgres_storage_mb
  tags = {
    environment = local.env
    app         = local.app
    managed_by  = "terraform"
  }
}
```

### 3. Add the CI/CD password variable

Each app gets its own masked CI variable per environment (no code change needed):

| Variable name | GitLab scope |
|---|---|
| `<APP>_POSTGRES_ADMIN_PASSWORD` | `dev` |
| `<APP>_POSTGRES_ADMIN_PASSWORD` | `stg` |
| `<APP>_POSTGRES_ADMIN_PASSWORD` | `prod` |

The variable name is derived automatically: `upper(app)` + `_POSTGRES_ADMIN_PASSWORD`.
For an app named `grafana`, the variable is `GRAFANA_POSTGRES_ADMIN_PASSWORD`.

### 4. Commit and push — the pipeline picks it up automatically

`run-all` will discover the new module on the next pipeline run. No CI changes required.

---

## Adding a New Module to an Existing App

If an app needs an additional resource type (e.g. a storage account alongside its postgres server):

### 1. Create a Terraform module under `modules/`

```
modules/
└── storage-account/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── versions.tf
```

### 2. Add a `terragrunt.hcl` in the app directory

```
environments/dev/<app-name>/
├── postgres-flex/
│   └── terragrunt.hcl    (existing)
└── storage-account/
    └── terragrunt.hcl    ← new
```

```hcl
include "root" {
  path = find_in_parent_folders()
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  app_vars = read_terragrunt_config(find_in_parent_folders("app.hcl"))

  env = local.env_vars.locals.env
  app = local.app_vars.locals.app
}

terraform {
  source = "../../../../modules/storage-account"
}

inputs = {
  storage_account_name = "st${local.app}${local.env}uksouth"
  resource_group_name  = "rg-${local.app}-${local.env}-uksouth"
  tags = {
    environment = local.env
    app         = local.app
    managed_by  = "terraform"
  }
}
```

Repeat the directory for `stg/` and `prod/`. Commit and push — done.

---

## Module Design

A module is a self-contained, reusable Terraform unit under `modules/`. It knows nothing about environments, apps, or CI — all of that context is injected by the Terragrunt layer above it.

### What a module is responsible for

- Declaring the resources it creates
- Defining its interface via `variables.tf`
- Exposing useful values via `outputs.tf`
- Pinning provider requirements in `versions.tf`

### What a module must not do

- Reference environment names, app names, or subscription IDs directly
- Construct resource names itself — names are passed in as variables
- Include a `provider` block — the root `terragrunt.hcl` generates this
- Include `terraform { required_providers {} }` at the module level if it is already in `versions.tf` — this causes a duplicate providers error

### Standard file structure

```
modules/<module-name>/
├── main.tf          # resource definitions
├── variables.tf     # all inputs declared here
├── outputs.tf       # values exposed to callers
└── versions.tf      # required_version + required_providers
```

### `versions.tf` — always present, never in the generate block

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}
```

The root `terragrunt.hcl` generates a `provider.tf` (containing only the `provider` block) at plan/apply time. The `required_providers` constraint stays here in the module.

### Variable conventions

| Pattern | Example |
|---|---|
| Names passed in, not constructed | `var.server_name`, `var.resource_group_name` |
| Sensitive values marked | `sensitive = true` on passwords |
| Sane defaults where safe | `default = "B_Standard_B1ms"` for SKU |
| No default for required identity inputs | `resource_group_name`, `server_name` — must always be explicit |

### The current `postgres-flex-server` module

The module creates three resources:

```
azurerm_resource_group                  one per app/env (named by caller)
azurerm_postgresql_flexible_server      one per app/env
azurerm_postgresql_flexible_server_database   zero or more, driven by var.databases list
```

Resource names, SKU, storage size, and admin credentials are all variables — none are hardcoded inside the module. The Terragrunt layer constructs the names from `env` and `app` locals:

```
rg-postgres-{app}-{env}-uksouth         ← resource group
psql-flex-{app}-{env}-uksouth           ← server
```

### Adding a variable to an existing module

1. Add the declaration to `variables.tf`
2. Reference it in `main.tf`
3. Pass the value in the relevant `environments/{env}/{app}/{module}/terragrunt.hcl` inputs block
4. If it should come from environment config, add it to `env.hcl` and read it via `local.env_vars.locals.<key>`

### Outputs

Always expose at minimum the resource group name, primary resource ID, and any connection endpoints. These can be consumed by dependent modules via Terragrunt `dependency` blocks if needed.

```hcl
output "server_fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "server_id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}
```

---

## Config Hierarchy Reference

```
environments/terragrunt.hcl          # provider block, backend config, shared inputs (location, env)
environments/{env}/env.hcl           # subscription ID, location, SKU tiers, pre-provisioned infra refs
environments/{env}/{app}/app.hcl     # app name only
environments/{env}/{app}/{module}/terragrunt.hcl   # module source + inputs
modules/{module}/                    # reusable Terraform module
```

Each layer inherits from the one above via `find_in_parent_folders()`. Only the module `terragrunt.hcl` needs to know about both `env.hcl` and `app.hcl` — everything else flows automatically.
