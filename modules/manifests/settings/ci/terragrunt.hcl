## ============================================================================================= ##
#  modules/manifests/settings/ci/terragrunt.hcl                                                   #
#                                                                                                 #
#  Terragrunt wrapper for settings module in CI environment.                                      #
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

inputs = {
  enabled = try(values.enabled, true)
  config = {
    apiserver            = try(values.config.apiserver, "https://kubernetes.default.svc")
    cluster_name         = try(values.config.cluster_name, "k8s")
    namespace            = "kube-system"
    service_account_name = "ci-deployer"
  }
}