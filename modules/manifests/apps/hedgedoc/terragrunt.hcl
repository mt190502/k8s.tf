## ============================================================================================= ##
#  modules/manifests/apps/hedgedoc/terragrunt.hcl                                                 #
#                                                                                                 #
#  Terragrunt wrapper for hedgedoc manifests.                                                     #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Dependencies:                                                                                  #
#    - cert-manager: Optional, Provides gateway_name and gateway_namespace for HTTPRoute          #
#    - cnpg: Optional, for PostgreSQL databases                                                   #
#    - psmdb-operator: Optional, for MongoDB databases                                            #
#                                                                                                 #
#  Usage: Copy this hedgedoc to your app directory and customize:                                 #
#    1. Replace "hedgedoc" with your app name                                                     #
#    2. Add/remove dependencies as needed                                                         #
#    3. Update inputs to match your variables.tf                                                  #
#                                                                                                 #
#  Apply order: (cert-manager/cnpg/psmdb-operator) -> [hedgedoc]                                  #
## ============================================================================================= ##
include "common" {
  path   = find_in_parent_folders("modules/common.hcl")
  expose = true
}

terraform {
  source = "./"

  after_hook "public_sites_apply" {
    commands     = ["apply"]
    run_on_error = false
    execute = try(values.enabled, true) ? [
      "bash",
      "${get_repo_root()}/.ci/public-domain.sh",
      "--name", "HedgeDoc",
      "--domain", "https://${try(values.config.hostname, "md")}.${try(values.config.domain, "mtaha.dev")}",
      "--statcodes", "200",
    ] : ["sh", "-c", "true"]
  }

  after_hook "public_sites_destroy" {
    commands     = ["destroy"]
    run_on_error = false
    execute = [
      "bash",
      "${get_repo_root()}/.ci/public-domain.sh",
      "--enabled", "false",
      "--name", "HedgeDoc",
      "--domain", "https://${try(values.config.hostname, "md")}.${try(values.config.domain, "mtaha.dev")}",
    ]
  }
}

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "kubernetes" {
      config_path = "~/.kube/config"
    }
    provider "helm" {
      kubernetes = {
        config_path = "~/.kube/config"
      }
    }
  EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.0.1" }
        helm       = { source = "hashicorp/helm",       version = "~> 3.1.1" }
      }
    }
  EOF
}

## --------------------------------------------------------------------------------------------- ##
#  Dependencies - enforce apply order and wire outputs from upstream modules.                     #
## --------------------------------------------------------------------------------------------- ##
dependency "cert_manager" {
  config_path = "../../core/cert-manager"
  mock_outputs = {
    gateway_name      = "mock-gateway"
    gateway_namespace = "mock-namespace"
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

#~ Uncomment if using postgres
# dependency "cnpg" {
#   config_path  = "../../core/cnpg"
#   skip_outputs = true
# }

#~ Uncomment if using mongo
# dependency "psmdb_operator" {
#   config_path  = "../../core/psmdb-operator"
#   skip_outputs = true
# }

inputs = {
  enabled = try(values.enabled, true)
  config = merge(
    try(values.config, {}),
    {
      gateway_name      = dependency.cert_manager.outputs.gateway_name
      gateway_namespace = dependency.cert_manager.outputs.gateway_namespace
      preferred_gateway = try(values.config.preferred_gateway, "cilium")
    }
  )
  secrets = try(values.secrets, {})
}