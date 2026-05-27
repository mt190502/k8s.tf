## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/terragrunt.hcl                                    #
#                                                                                                 #
#  Terragrunt wrapper for kube-prometheus-stack monitoring components.                            #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Apply order: longhorn -> (kps/pre) -> cert-manager -> [kube-prometheus-stack]                  #
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

  after_hook "public_sites_apply" {
    commands     = ["apply"]
    run_on_error = false
    execute = try(values.enabled, true) ? [
      "bash",
      "${get_repo_root()}/.ci/public-domain.sh",
      "--name", "Grafana",
      "--domain", "https://${try(values.config.hostname, "dash")}.${try(values.config.domain, "example.com")}",
      "--statcodes", try(values.config.basic_auth, false) ? "200:401:403" : "200",
    ] : ["sh", "-c", "true"]
  }

  after_hook "public_sites_destroy" {
    commands     = ["destroy"]
    run_on_error = false
    execute = [
      "bash",
      "${get_repo_root()}/.ci/public-domain.sh",
      "--enabled", "false",
      "--name", "Grafana",
      "--domain", "https://${try(values.config.hostname, "dash")}.${try(values.config.domain, "example.com")}",
    ]
  }
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
dependency "cert_manager" {
  config_path = "../cert-manager"
  mock_outputs = {
    gateway_name      = "mock-gateway"
    gateway_namespace = "mock-namespace"
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

dependency "longhorn" {
  config_path  = "../longhorn"
  skip_outputs = true
}

dependency "pre" {
  config_path  = "./pre"
  skip_outputs = true
}

dependency "gotify" {
  config_path = "../../apps/gotify"
  mock_outputs = {
    namespace        = "gotify"
    bridge_endpoints = { alertmanager = "http://alertmanager-gotify-bridge.gotify.svc.cluster.local:8080/gotify_webhook", loki = "http://loki-gotify-bridge.gotify.svc.cluster.local:8080/gotify_webhook" }
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

inputs = {
  enabled = try(values.enabled, true)
  config = merge(
    try(values.config, {}),
    {
      gateway_name            = dependency.cert_manager.outputs.gateway_name
      gateway_namespace       = dependency.cert_manager.outputs.gateway_namespace
      preferred_gateway       = try(values.config.preferred_gateway, "cilium")
      gotify_bridge_endpoints = try(dependency.gotify.outputs.bridge_endpoints, {})
    }
  )
  secrets = try(values.secrets, {})
}