## ============================================================================================= ##
#  modules/infra/tailscale/post/terragrunt.hcl                                                    #
#                                                                                                 #
#  Terragrunt wrapper for the Tailscale post stage --- discovers node IPs after hetzner/post.     #
#                                                                                                 #
#  Required Inputs                                                                                #
#   config.dualstack, secrets.client_id, secrets.client_secret, secrets.tailnet                   #
#   deps.nodes (from hetzner/post dependency)                                                     #
#                                                                                                 #
#  Apply order:                                                                                   #
#   talos/pre -> hetzner/post -> [tailscale/post] -> talos/post -> cloudflare/post                #
## ============================================================================================= ##
include "common" {
  path   = find_in_parent_folders("modules/common.hcl")
  expose = true
}

exclude {
  if      = !try(values.enabled, true)
  actions = ["all"]
}

terraform {
  source = "./"
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        tailscale = { source = "tailscale/tailscale", version = "~> 0.28.0" }
        null      = { source = "hashicorp/null",      version = "~> 3.2.4" }
      }
    }
  EOF
}

generate "secrets" {
  path      = "secrets.auto.tfvars"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    secrets = {
      client_id     = "${try(values.secrets.client_id, "") != "" ? values.secrets.client_id : include.common.locals.mock_tailscale_oauth_id}"
      client_secret = "${try(values.secrets.client_secret, "") != "" ? values.secrets.client_secret : include.common.locals.mock_tailscale_oauth_secret}"
      tailnet       = "${try(values.secrets.tailnet, "") != "" ? values.secrets.tailnet : include.common.locals.mock_tailscale_tailnet}"
    }
  EOF
}

## --------------------------------------------------------------------------------------------- ##
#  Dependencies -  enforce apply order and wire outputs from upstream modules as inputs.          #
## --------------------------------------------------------------------------------------------- ##
dependency "hetzner_post" {
  enabled      = try(values.rootvars.hetzner.enabled, false)
  config_path  = "../../hetzner/post"
  skip_outputs = contains(include.common.locals.skip_outputs_commands, get_terraform_command())
  mock_outputs = {
    controlplane_nodes = {}
    nodes              = {}
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

inputs = {
  enabled = try(values.enabled, true)
  config = {
    dualstack = try(values.config.dualstack, true)
  }
  deps = {
    nodes = try(values.rootvars.hetzner.enabled, false) ? {
      for name, node in try(dependency.hetzner_post.outputs.nodes, {}) : name => {
        name = node.name
        role = node.role
      }
    } : {}
  }
  rootvars = try(values.rootvars, {})
}