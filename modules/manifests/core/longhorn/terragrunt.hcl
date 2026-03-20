## ============================================================================================= ##
#  modules/manifests/core/longhorn/terragrunt.hcl                                                 #
#                                                                                                 #
#  Terragrunt wrapper for Longhorn (cluster storage).                                             #
#  Applies only after talos/post and cloudflare/post are complete.                                #
#  Runs readiness checks before apply, then unlocks other core manifest units.                    #
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
  before_hook "wait_for_cluster" {
    commands = ["apply"]
    execute = [
      "sh", "-c",
      <<-EOT
        set -euo pipefail

        echo "Waiting for API server DNS to propagate..."
        APISERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' | sed 's|https://||' | cut -d: -f1)
        DEADLINE=$(( $(date +%s) + 300 ))
        until host "$APISERVER" 1.1.1.1 >/dev/null 2>&1; do
          if [ "$(date +%s)" -ge "$DEADLINE" ]; then
            echo "Timed out waiting for DNS propagation of $APISERVER"
            exit 1
          fi
          echo "  $APISERVER not yet resolvable, retrying in 5s..."
          sleep 5
        done
        echo "DNS resolved --- $APISERVER is live."

        echo "Waiting for node objects to appear..."
        DEADLINE=$(( $(date +%s) + 600 ))
        until kubectl get nodes --no-headers 2>/dev/null | grep -q .; do
          if [ "$(date +%s)" -ge "$DEADLINE" ]; then
            echo "Timed out waiting for Kubernetes node objects to appear"
            exit 1
          fi
          echo "  no nodes found yet, retrying in 5s..."
          sleep 5
        done

        echo "Waiting for all nodes to be Ready..."
        kubectl wait node --all \
          --for=condition=Ready \
          --timeout=600s

        echo "Waiting for kube-system pods to appear..."
        DEADLINE=$(( $(date +%s) + 600 ))
        until kubectl get pod -n kube-system --no-headers 2>/dev/null | grep -q .; do
          if [ "$(date +%s)" -ge "$DEADLINE" ]; then
            echo "Timed out waiting for kube-system pods to appear"
            exit 1
          fi
          echo "  no kube-system pods found yet, retrying in 5s..."
          sleep 5
        done

        echo "Waiting for all kube-system pods to be Running or Succeeded..."
        kubectl wait pod --all \
          --namespace=kube-system \
          --for=condition=Ready \
          --timeout=600s \
          --field-selector=status.phase!=Succeeded

        echo "Cluster is ready --- proceeding with manifest units."
      EOT
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
        kubernetes = { source = "hashicorp/kubernetes", version = "${include.common.locals.providers.kubernetes.version}" }
        helm       = { source = "hashicorp/helm",       version = "${include.common.locals.providers.helm.version}" }
      }
    }
  EOF
}

## --------------------------------------------------------------------------------------------- ##
#  Dependencies -  enforce apply order and wire outputs from upstream modules as inputs.          #
## --------------------------------------------------------------------------------------------- ##
dependency "cloudflare_post" {
  config_path                             = "${get_repo_root()}/.terragrunt-stack/infra/cloudflare/post"
  skip_outputs                            = true
  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

dependency "talos_post" {
  config_path                             = "${get_repo_root()}/.terragrunt-stack/infra/talos/post"
  skip_outputs                            = true
  mock_outputs                            = {}
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

inputs = {
  enabled = try(values.enabled, true)
  versions = {
    chart = values.versions.chart
  }
}