## ============================================================================================= ##
#  modules/infra/talos/pre/terragrunt.hcl                                                         #
#                                                                                                 #
#  Terragrunt wrapper for the Talos pre stage (machine secret + config generation).               #
#                                                                                                 #
#  Required Inputs                                                                                #
#   - cilium_version, kubernetes_version, talos_version (strings)                                 #
#   - cluster_name, cluster_url, ipcfg (cluster identity + networking)                            #
#   - dualstack, kubeprism, kubespan (feature flags)                                              #
#   - nodes (map: name, role, type, location, taints)                                             #
#   - tailscale_auth_key (sensitive)                                                              #
#                                                                                                 #
#  Apply order:                                                                                   #
#   [talos/pre] -> hetzner/post -> tailscale/post -> talos/post -> cloudflare/post                #
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
  source = "${get_repo_root()}/modules/infra/talos//pre"
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        talos = { source = "siderolabs/talos", version = "~> 0.10.1" }
      }
    }
  EOF
}

generate "secrets" {
  path      = "secrets.auto.tfvars"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    secrets = {
      auth_key = "${values.secrets.auth_key}"
    }
  EOF
}

inputs = {
  enabled = try(values.enabled, true)
  config = {
    cluster_name = try(values.config.cluster_name, "")
    cluster_url  = try(values.config.cluster_url, null)
    dualstack    = try(values.config.dualstack, true)
    ipcfg        = try(values.config.ipcfg, null)
    kubeprism    = try(values.config.kubeprism, true)
    kubespan     = try(values.config.kubespan, false)
    nodes        = try(values.config.nodes, {})
  }
  versions = {
    cilium     = try(values.versions.cilium, "")
    kubernetes = try(values.versions.kubernetes, "")
    talos      = try(values.versions.talos, "")
  }
}