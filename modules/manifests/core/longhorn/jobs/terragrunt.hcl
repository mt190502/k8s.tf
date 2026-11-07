## ============================================================================================= ##
#  modules/manifests/core/longhorn/jobs/terragrunt.hcl                                            #
#                                                                                                 #
#  Terragrunt wrapper for Longhorn RecurringJobs (scheduled snapshots and backups).               #
#  The longhorn.io RecurringJob CRDs ship with the Longhorn chart in core/longhorn, so            #
#  these CRs are planned there only after that unit completed (see recurringjobs.tf).             #
#  Config is provided from stack values.                                                          #
#                                                                                                 #
#  Apply order: longhorn -> [jobs]                                                                #
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
  EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.5.0" }
      }
    }
  EOF
}

## --------------------------------------------------------------------------------------------- ##
#  Dependencies - enforce apply order and wire outputs from upstream modules.                     #
## --------------------------------------------------------------------------------------------- ##
dependency "longhorn" {
  config_path  = ".."
  skip_outputs = true
}

inputs = {
  enabled = try(values.enabled, false)
}
