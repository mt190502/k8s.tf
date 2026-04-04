## ============================================================================================= ##
#  modules/manifests/core/traefik/terragrunt.hcl                                                  #
#                                                                                                 #
#  Terragrunt wrapper for Traefik (Gateway API ingress controller).                               #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Apply order: cert-manager -> [traefik]                                                         #
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
        kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.0.1" }
        helm       = { source = "hashicorp/helm",       version = "~> 3.1.1" }
      }
    }
  EOF
}

dependency "cert_manager" {
  config_path = "../cert-manager"
  mock_outputs = {
    certificate_name      = "wildcard-mock.local-tls"
    certificate_namespace = "cert-manager"
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

inputs = {
  enabled = try(values.enabled, false)
  config = {
    gateway_name = try(values.config.gateway_name, "traefik-gateway")
    dns_domain   = try(values.config.dns_domain, "mock.local")
    tls = {
      secret_name      = dependency.cert_manager.outputs.certificate_name
      secret_namespace = dependency.cert_manager.outputs.certificate_namespace
    }
  }
}