## ============================================================================================= ##
#  modules/infra/cloudflare/post/terragrunt.hcl                                                   #
#                                                                                                 #
#  Terragrunt wrapper for the Cloudflare post stage --- creates all cluster DNS records.          #
#                                                                                                 #
#  Required Inputs                                                                                #
#   config.cluster_url (main, apiserver, dns), secrets.api_token, secrets.zone_id                 #
#   dualstack                                                                                     #
#   deps.nodes (from hetzner/post), deps.tailscale.ipv4_addresses, deps.tailscale.ipv6_addresses  #
#                                                                                                 #
#  Apply order:                                                                                   #
#   talos/pre -> hetzner/post -> tailscale/post -> talos/post -> [cloudflare/post]                #
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
        cloudflare = { source = "cloudflare/cloudflare", version = "~> 5.18.0" }
      }
    }
  EOF
}

generate "secrets" {
  path      = "secrets.auto.tfvars"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    secrets = {
      api_token = "${try(values.secrets.api_token, "") != "" ? values.secrets.api_token : include.common.locals.mock_cloudflare_api_token}"
      zone_id   = "${try(values.secrets.zone_id, "") != "" ? values.secrets.zone_id : include.common.locals.mock_cloudflare_zone_id}"
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
    controlplane_nodes = include.common.locals.mock_nodes_minimal
    nodes              = include.common.locals.mock_nodes_minimal
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

dependency "tailscale_post" {
  enabled      = try(values.rootvars.tailscale.enabled, false)
  config_path  = "../../tailscale/post"
  skip_outputs = contains(include.common.locals.skip_outputs_commands, get_terraform_command())
  mock_outputs = {
    node_ipv4 = include.common.locals.mock_tailscale_ipv4
    node_ipv6 = include.common.locals.mock_tailscale_ipv6
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

dependency "talos_post" {
  config_path                             = "../../talos/post"
  skip_outputs                            = true
  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

inputs = {
  enabled = try(values.enabled, true)
  config = {
    cluster_url = {
      main      = try(values.config.cluster_url.main, "mock.example.com")
      apiserver = try(values.config.cluster_url.apiserver, "k8s.mock.example.com")
      dns       = try(values.config.cluster_url.dns, "mock.example.com")
    }
    dualstack = try(values.config.dualstack, true)
  }
  deps = {
    nodes = try(values.rootvars.hetzner.enabled, false) ? {
      for name, node in dependency.hetzner_post.outputs.nodes : name => {
        name         = node.name
        role         = node.role
        ipv4_address = node.ipv4_address
        ipv6_address = node.ipv6_address
      }
    } : {}
    tailscale = try(values.rootvars.tailscale.enabled, false) ? {
      ipv4_addresses = dependency.tailscale_post.outputs.node_ipv4
      ipv6_addresses = dependency.tailscale_post.outputs.node_ipv6
      } : {
      ipv4_addresses = {}
      ipv6_addresses = {}
    }
  }
  rootvars = try(values.rootvars, {})
}