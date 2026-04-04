## ============================================================================================= ##
#  modules/manifests/core/tailscale-operator/terragrunt.hcl                                       #
#                                                                                                 #
#  Terragrunt wrapper for tailscale-operator module.                                              #
#  Apply order: longhorn -> [tailscale-operator] -> cert-manager                                  #
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

generate "secrets" {
  path      = "secrets.auto.tfvars"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    secrets = {
      client_id     = "${try(values.secrets.client_id, "")}"
      client_secret = "${try(values.secrets.client_secret, "")}"
      auth_key      = "${try(values.secrets.auth_key, "")}"
    }
  EOF
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
        null       = { source = "hashicorp/null",       version = "~> 3.2.4" }
        external   = { source = "hashicorp/external",   version = "~> 2.3.1" }
      }
    }
  EOF
}

## --------------------------------------------------------------------------------------------- ##
#  Dependencies - enforce apply order and wire outputs from upstream modules as inputs.           #
## --------------------------------------------------------------------------------------------- ##
dependency "longhorn" {
  config_path  = "../longhorn"
  skip_outputs = true
}

inputs = {
  enabled = try(values.enabled, true)
  config = {
    subnet_router_advertised_cidrs = try(values.config.subnet_router_advertised_cidrs, [])
  }
  secrets = {
    auth_key      = try(values.secrets.auth_key, "")
    client_id     = try(values.secrets.client_id, "")
    client_secret = try(values.secrets.client_secret, "")
  }
  chart_version = try(values.chart_version, "")
}