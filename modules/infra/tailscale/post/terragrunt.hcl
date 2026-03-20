## ============================================================================================= ##
#  modules/infra/tailscale/post/terragrunt.hcl                                                    #
#                                                                                                 #
#  Terragrunt wrapper for the Tailscale post stage --- discovers node IPs after hetzner/post.     #
#                                                                                                 #
#  Required Inputs                                                                                #
#   - dualstack, tailscale_auth_key, tailscale_client_id, tailscale_client_secret                 #
#   - tailscale_tailnet                                                                           #
#   - nodes (from hetzner/post dependency)                                                        #
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
        tailscale = { source = "tailscale/tailscale", version = "${include.common.locals.providers.tailscale.version}" }
        null      = { source = "hashicorp/null",      version = "${include.common.locals.providers.null.version}" }
      }
    }
  EOF
}

generate "secrets" {
  path      = "secrets.auto.tfvars"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    secrets = {
      auth_key      = "${try(values.secrets.auth_key, "") != "" ? values.secrets.auth_key : include.common.locals.mock_tailscale_auth_key}" 
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
  config_path = "../../hetzner/post"
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
  nodes = {
    for name, node in try(dependency.hetzner_post.outputs.nodes, {}) : name => {
      name = node.name
      role = node.role
    }
  }
}