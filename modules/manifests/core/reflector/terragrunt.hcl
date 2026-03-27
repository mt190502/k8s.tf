## ============================================================================================= ##
#  modules/manifests/core/reflector/terragrunt.hcl                                                #
#                                                                                                 #
#  Terragrunt wrapper for Reflector (secret/configmap sync).                                      #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Apply order: longhorn -> [reflector] -> cert-manager                                           #
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
dependency "longhorn" {
  config_path  = "../longhorn"
  skip_outputs = true
}

inputs = {
  enabled = try(values.enabled, true)
  config = {
    wildcard_reflection_namespaces = try(values.config.wildcard_reflection_namespaces, [])
  }
  chart_version = try(values.chart_version, "")
}