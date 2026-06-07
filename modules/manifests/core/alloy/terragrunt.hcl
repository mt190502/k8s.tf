## ============================================================================================= ##
#  modules/manifests/core/alloy/terragrunt.hcl                                                    #
#                                                                                                 #
#  Terragrunt wrapper for Granfana's alloy helm chart.                                            #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Apply order: kps -> [alloy]                                                                    #
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
#  Dependencies -  enforce apply order and wire outputs from upstream modules as inputs.          #
## --------------------------------------------------------------------------------------------- ##
dependency "kube_prometheus_stack" {
  config_path = "../kube-prometheus-stack"
  mock_outputs = {
    namespace = "monitoring"
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

inputs = {
  enabled = try(values.enabled, true)
  config = {
    kps_namespace = dependency.kube_prometheus_stack.outputs.namespace
  }
}
