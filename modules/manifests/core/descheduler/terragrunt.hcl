## ============================================================================================= ##
#  modules/manifests/core/descheduler/terragrunt.hcl                                              #
#                                                                                                 #
#  Terragrunt wrapper for Kubernetes Descheduler.                                                 #
#  Config is provided from stack values.                                                          #
## ============================================================================================= ##
include "common" {
  path   = find_in_parent_folders("modules/common.hcl")
  expose = true
}

exclude {
  if      = !try(values.enabled, false)
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
        kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.2.0" }
        helm       = { source = "hashicorp/helm",       version = "~> 3.3.0" }
      }
    }
  EOF
}

dependency "kube_prometheus_stack_pre" {
  config_path  = "../kube-prometheus-stack/pre"
  skip_outputs = true
}

inputs = {
  enabled = try(values.enabled, false)
  config = {
    descheduling_interval = try(values.config.descheduling_interval, "5m")
    replicas              = try(values.config.replicas, 2)
  }
}
