## ============================================================================================= ##
#  modules/infra/hetzner/post/terragrunt.hcl                                                      #
#                                                                                                 #
#  Terragrunt wrapper for the Hetzner post stage --- creates servers and firewall.                #
#                                                                                                 #
#  Required Inputs                                                                                #
#   - config.cluster_name, config.dualstack, config.firewall, secrets.api_token, config.images    #
#   - nodes (list: name, role, arch, location, image_id, server_type, taints)                     #
#   - deps.talos.machine_configurations (from talos/pre dependency)                               #
#                                                                                                 #
#  Apply order:                                                                                   #
#   talos/pre -> [hetzner/post] -> tailscale/post -> talos/post -> cloudflare/post                #
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

locals {
  mock_user_data = { for node in try(values.config.nodes, []) : node.name => "mock-machine-config" }
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        hcloud = { source = "hetznercloud/hcloud", version = "${include.common.locals.providers.hcloud.version}" }
      }
    }
  EOF
}

generate "secrets" {
  path      = "secrets.auto.tfvars"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    secrets = {
      api_token = "${try(values.secrets.api_token, "") != "" ? values.secrets.api_token : include.common.locals.mock_hcloud_api_token}"
    }
  EOF
}

## --------------------------------------------------------------------------------------------- ##
#  Dependencies -  enforce apply order and wire outputs from upstream modules as inputs.          #
## --------------------------------------------------------------------------------------------- ##
dependency "talos_pre" {
  config_path  = "../../talos/pre"
  skip_outputs = contains(include.common.locals.skip_outputs_commands, get_terraform_command())
  mock_outputs = {
    machine_configurations = local.mock_user_data
    machine_secrets = {
      client_configuration = {
        ca_certificate     = "mock"
        client_certificate = "mock"
        client_key         = "mock"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

inputs = {
  enabled = try(values.enabled, true)
  config = {
    assignments  = try(values.config.assignments, {})
    cluster_name = try(values.config.cluster_name, "")
    dualstack    = try(values.config.dualstack, true)
    firewall = {
      enabled = try(values.config.firewall.enabled, false)
      rules   = try(values.config.firewall.rules, [])
    }
    images = {
      amd64 = {
        id   = try(values.config.images.amd64.id, "")
        code = try(values.config.images.amd64.code, "")
      }
      arm64 = {
        id   = try(values.config.images.arm64.id, "")
        code = try(values.config.images.arm64.code, "")
      }
    }
    nodes = try(values.config.nodes, [])
    private_network = {
      enabled = try(values.config.private_network.enabled, false)
      cidr    = try(values.config.private_network.cidr, "10.0.0.0/16")
    }
  }
  deps = {
    talos = {
      machine_configurations = dependency.talos_pre.outputs.machine_configurations
    }
  }
}