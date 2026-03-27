## ============================================================================================= ##
#  modules/manifests/core/cert-manager/terragrunt.hcl                                             #
#                                                                                                 #
#  Terragrunt wrapper for cert-manager (ACME DNS01 certificates).                                 #
#  Deploys issuer, wildcard cert, and gateway resources.                                          #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Apply order: reflector/cnpg/kps -> [cert-manager]                                              #
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
      api_token = "${values.secrets.api_token}"
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
        kubernetes = { source = "hashicorp/kubernetes", version = "${include.common.locals.providers.kubernetes.version}" }
        helm       = { source = "hashicorp/helm",       version = "${include.common.locals.providers.helm.version}" }
        null       = { source = "hashicorp/null",       version = "${include.common.locals.providers.null.version}" }
        external   = { source = "hashicorp/external",   version = "${include.common.locals.providers.external.version}" }
      }
    }
  EOF
}

## --------------------------------------------------------------------------------------------- ##
#  Dependencies - enforce apply order and wire outputs from upstream modules as inputs.           #
## --------------------------------------------------------------------------------------------- ##
dependency "cnpg" {
  config_path  = "../cnpg"
  skip_outputs = true
}

dependency "kube_prometheus_stack" {
  config_path  = "../kube-prometheus-stack"
  skip_outputs = true
}

dependency "reflector" {
  config_path  = "../reflector"
  skip_outputs = true
}

inputs = {
  enabled = try(values.enabled, true)
  config = {
    acme_email                     = try(values.config.acme_email, "")
    dns_domain                     = try(values.config.dns_domain, "")
    wildcard_reflection_namespaces = try(values.config.wildcard_reflection_namespaces, [])
  }
  secrets = {
    api_token = try(values.secrets.api_token, "")
  }
  chart_version = try(values.chart_version, "")
}