## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/terragrunt.hcl                                    #
#                                                                                                 #
#  Terragrunt wrapper for kube-prometheus-stack monitoring components.                            #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Apply order: longhorn -> [kube-prometheus-stack] -> cert-manager                               #
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
dependency "longhorn" {
  config_path  = "../longhorn"
  skip_outputs = true
}

inputs = {
  enabled = try(values.enabled, true)
}