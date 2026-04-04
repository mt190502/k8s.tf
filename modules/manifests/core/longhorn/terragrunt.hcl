## ============================================================================================= ##
#  modules/manifests/core/longhorn/terragrunt.hcl                                                 #
#                                                                                                 #
#  Terragrunt wrapper for Longhorn (cluster storage).                                             #
#  First manifest unit to apply after infra stack completes.                                      #
#                                                                                                 #
#  Apply order: (infra) cloudflare/post -> [longhorn] -> reflector/cnpg/kps -> cert-manager -> .. #
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

inputs = {
  enabled       = try(values.enabled, true)
}