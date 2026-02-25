# =============================================================================
# Root Terragrunt configuration
#
# All child configs include this file via:
#   include "root" { path = find_in_parent_folders() }
#
# Responsibilities:
#   - Generate the azurerm provider block
#   - Configure the GitLab-managed HTTP backend per environment/module path
#   - Expose common inputs (location, env) to all child modules
# =============================================================================

locals {
  # Read the env.hcl that lives in each environment folder (prod / non-prod).
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals.env

  # Shared values — subscription ID and region live in common.hcl.
  common          = read_terragrunt_config("${get_terragrunt_dir()}/../common.hcl")
  subscription_id = local.common.locals.subscription_id
  location        = local.common.locals.location

  # ---------------------------------------------------------------------------
  # GitLab HTTP backend
  # CI_API_V4_URL and CI_PROJECT_ID are injected automatically by GitLab CI.
  # When running locally, fall back to sensible defaults so `plan` still works
  # with a local backend override (e.g. -backend-config flags).
  # ---------------------------------------------------------------------------
  gitlab_api_url    = get_env("CI_API_V4_URL", "https://gitlab.com/api/v4")
  gitlab_project_id = get_env("CI_PROJECT_ID", "0")

  # Build a unique state name from the directory path relative to this file,
  # e.g. "prod-postgres-flex" or "non-prod-postgres-flex".
  state_name    = replace(path_relative_to_include(), "/", "-")
  state_address = "${local.gitlab_api_url}/projects/${local.gitlab_project_id}/terraform/state/${local.state_name}"
}

# ---------------------------------------------------------------------------
# Provider generation
# The azurerm provider reads ARM_* env vars automatically; we only need to
# pin the required_providers block here.
# ---------------------------------------------------------------------------
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.5.0"
      required_providers {
        azurerm = {
          source  = "hashicorp/azurerm"
          version = "~> 3.90"
        }
      }
    }

    provider "azurerm" {
      features {}
      subscription_id = "${local.subscription_id}"
      # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID are supplied via environment variables
    }
  EOF
}

# ---------------------------------------------------------------------------
# GitLab-managed Terraform HTTP backend
# CI_JOB_TOKEN is available in every GitLab CI job automatically.
# ---------------------------------------------------------------------------
remote_state {
  backend = "http"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    address        = local.state_address
    lock_address   = "${local.state_address}/lock"
    unlock_address = "${local.state_address}/lock"
    method         = "POST"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
    username       = "gitlab-ci-token"
    password       = get_env("CI_JOB_TOKEN", "")
  }
}

# ---------------------------------------------------------------------------
# Common inputs passed to every child module
# ---------------------------------------------------------------------------
inputs = {
  location = local.location
  env      = local.env
}
