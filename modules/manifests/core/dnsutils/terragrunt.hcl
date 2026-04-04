## ============================================================================================= ##
#  modules/manifests/core/dnsutils/terragrunt.hcl                                                 #
#                                                                                                 #
#  Terragrunt wrapper for dnsutils manifests.                                                     #
#                                                                                                 #
#  Apply order: longhorn -> reflector/cnpg/kps -> cert-manager -> [dnsutils]                      #
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
  EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.0.1" }
      }
    }
  EOF
}

## --------------------------------------------------------------------------------------------- ##
#  Dependencies -  enforce apply order and wire outputs from upstream modules as inputs.          #
## --------------------------------------------------------------------------------------------- ##
dependency "cert_manager" {
  config_path  = "../cert-manager"
  skip_outputs = true
}

inputs = {
  enabled = try(values.enabled, true)
}