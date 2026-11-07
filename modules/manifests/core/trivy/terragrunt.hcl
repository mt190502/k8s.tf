## ============================================================================================= ##
#  modules/manifests/core/trivy/terragrunt.hcl                                                    #
#                                                                                                 #
#  Terragrunt wrapper for Aqua Security's trivy-operator helm chart.                              #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Apply order: kps/pre -> [trivy]                                                                #
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
        kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.4.0" }
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
    built_in_trivy_server      = try(values.config.built_in_trivy_server, true)
    severity                   = try(values.config.severity, "CRITICAL,HIGH")
    ignore_unfixed             = try(values.config.ignore_unfixed, true)
    scan_jobs_concurrent_limit = try(values.config.scan_jobs_concurrent_limit, 3)
    scan_report_ttl            = try(values.config.scan_report_ttl, "168h")
    exclude_namespaces         = try(values.config.exclude_namespaces, ["kube-system", "trivy-system"])
  }
}
