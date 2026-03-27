## ============================================================================================= ##
#  modules/manifests/apps/nightscout/terragrunt.hcl                                               #
#                                                                                                 #
#  Terragrunt wrapper for Nightscout (CGM data visualization app) manifests.                      #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Apply order: psmdb-operator -> [nightscout]                                                    #
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
        kubernetes = { source = "hashicorp/kubernetes", version = "${include.common.locals.providers.kubernetes.version}" }
        helm       = { source = "hashicorp/helm",       version = "${include.common.locals.providers.helm.version}" }
      }
    }
  EOF
}

## --------------------------------------------------------------------------------------------- ##
#  Dependencies -  enforce apply order and wire outputs from upstream modules as inputs.          #
## --------------------------------------------------------------------------------------------- ##
dependency "cert_manager" {
  config_path = "../../core/cert-manager"
  mock_outputs = {
    gateway_name = "mock-gateway"
    namespace    = "mock-namespace"
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

dependency "psmdb-operator" {
  config_path  = "../../core/psmdb-operator"
  skip_outputs = true
}

inputs = {
  enabled = try(values.enabled, true)
  config = merge(
    try(values.config, {}),
    {
      gateway_name      = dependency.cert_manager.outputs.gateway_name
      gateway_namespace = dependency.cert_manager.outputs.namespace
    }
  )
  secrets       = try(values.secrets, { api_secret = "" })
  image_version = try(values.image_version, "")
}