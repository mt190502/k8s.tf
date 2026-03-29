## ============================================================================================= ##
#  modules/manifests/apps/template/terragrunt.hcl                                                 #
#                                                                                                 #
#  Terragrunt wrapper for template manifests.                                                     #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Dependencies:                                                                                  #
#    - cert-manager: Optional, Provides gateway_name and gateway_namespace for HTTPRoute          #
#    - cnpg: Optional, for PostgreSQL databases                                                   #
#    - psmdb-operator: Optional, for MongoDB databases                                            #
#                                                                                                 #
#  Usage: Copy this template to your app directory and customize:                                 #
#    1. Replace "template" with your app name                                                     #
#    2. Add/remove dependencies as needed                                                         #
#    3. Update inputs to match your variables.tf                                                  #
#                                                                                                 #
#  Apply order: (cert-manager/cnpg/psmdb-operator) -> [template]                                  #
## ============================================================================================= ##
include "common" {
  path   = find_in_parent_folders("modules/common.hcl")
  expose = true
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
#  Dependencies - enforce apply order and wire outputs from upstream modules.                     #
## --------------------------------------------------------------------------------------------- ##
#~ Uncomment if using httproute and another cert depended states
# dependency "cert_manager" {
#   config_path = "../../core/cert-manager"
#   mock_outputs = {
#     gateway_name      = "mock-gateway"
#     gateway_namespace = "mock-namespace"
#   }
#   mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
#   mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
# }

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
      preferred_gateway = values.config.preferred_gateway != null ? values.config.preferred_gateway : "cilium"
    }
  )
  secrets       = try(values.secrets, {})
  image_version = try(values.image_version, "")
  chart_version = try(values.chart_version, "")
}