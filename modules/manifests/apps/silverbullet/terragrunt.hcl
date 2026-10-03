## ============================================================================================= ##
#  modules/manifests/apps/silverbullet/terragrunt.hcl                                             #
#                                                                                                 #
#  Terragrunt wrapper for silverbullet manifests.                                                 #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Dependencies:                                                                                  #
#    - cert-manager: Optional, Provides gateway_name and gateway_namespace for HTTPRoute          #
#                                                                                                 #
#  Apply order: cert-manager -> [silverbullet]                                                    #
## ============================================================================================= ##
include "common" {
  path   = find_in_parent_folders("modules/common.hcl")
  expose = true
}

exclude {
  if      = !try(values.enabled, false)
  actions = ["all"]
}

terraform {
  source = "./"

  after_hook "public_sites_apply" {
    commands     = ["apply"]
    run_on_error = false
    execute = try(values.enabled, false) ? [
      "bash",
      "${get_repo_root()}/.ci/public-domain.sh",
      "--name", "SilverBullet",
      "--domain", "https://${try(values.config.hostname, "md")}.${try(values.config.domain, "mtaha.dev")}",
      "--statcodes", try(values.config.basic_auth, true) ? "200:401:403" : "200",
    ] : ["sh", "-c", "true"]
  }

  after_hook "public_sites_destroy" {
    commands     = ["destroy"]
    run_on_error = false
    execute = [
      "bash",
      "${get_repo_root()}/.ci/public-domain.sh",
      "--enabled", "false",
      "--name", "SilverBullet",
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
  EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.3.0" }
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

inputs = {
  enabled = try(values.enabled, false)
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
