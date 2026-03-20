## ============================================================================================= ##
#  modules/infra/talos/post/terragrunt.hcl                                                        #
#                                                                                                 #
#  Terragrunt wrapper for the Talos post stage (config apply, bootstrap, kubeconfig).             #
#  After apply: merges kubeconfig into ~/.kube/config and writes ~/.talos/config.                 #
#  After destroy: removes cluster entries from kubeconfig and deletes talosconfig.                #
#                                                                                                 #
#  Required Inputs                                                                                #
#   - cluster_name, cluster_url.apiserver, dualstack, first_controlplane                          #
#                                                                                                 #
#  Apply order:                                                                                   #
#   talos/pre -> hetzner/post -> tailscale/post -> [talos/post] -> cloudflare/post                #
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
  after_hook "write_kubeconfig" {
    commands     = ["apply"]
    run_on_error = false
    execute = [
      "sh", "-c",
      <<-EOT
        set -euo pipefail
        TMPKUBE=$(mktemp /tmp/talos-kubeconfig-XXXXXX.yaml)
        trap 'rm -f "$TMPKUBE"' EXIT
        tofu output -raw kubeconfig > "$TMPKUBE"
        mkdir -p "$HOME/.kube"
        if [ -f "$HOME/.kube/config" ]; then
          KUBECONFIG="$TMPKUBE:$HOME/.kube/config" \
            kubectl config view --merge --flatten > "$HOME/.kube/config.tmp"
          mv "$HOME/.kube/config.tmp" "$HOME/.kube/config"
        else
          cp "$TMPKUBE" "$HOME/.kube/config"
        fi
        chmod 600 "$HOME/.kube/config"
        echo "kubeconfig merged into $HOME/.kube/config"
      EOT
    ]
  }

  after_hook "write_talosconfig" {
    commands     = ["apply"]
    run_on_error = false
    execute = [
      "sh", "-c",
      <<-EOT
        set -euo pipefail
        tofu output -raw talosconfig > "$HOME/.talos/config"
        chmod 600 "$HOME/.talos/config"
        echo "Talos client configuration written to $HOME/.talos/config"
      EOT
    ]
  }

  after_hook "destroy_kubeconfig" {
    commands     = ["destroy"]
    run_on_error = false
    execute = [
      "sh", "-c",
      <<-EOT
        set -euo pipefail
        kubectl config delete-cluster "${values.config.cluster_name}" || true
        kubectl config delete-context "admin@${values.config.cluster_name}" || true
        kubectl config delete-user "admin@${values.config.cluster_name}" || true
        echo "kubeconfig entries for cluster '${values.config.cluster_name}' removed from $HOME/.kube/config"
      EOT
    ]
  }

  after_hook "destroy_talosconfig" {
    commands     = ["destroy"]
    run_on_error = false
    execute = [
      "sh", "-c",
      <<-EOT
        set -euo pipefail
        if [ -f "$HOME/.talos/config" ]; then
          rm -f "$HOME/.talos/config"
          echo "Talos client configuration removed from $HOME/.talos/config"
        fi
      EOT
    ]
  }
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        talos = { source = "siderolabs/talos", version = "${include.common.locals.providers.talos.version}" }
      }
    }
  EOF
}

## --------------------------------------------------------------------------------------------- ##
#  Dependencies -  enforce apply order and wire outputs from upstream modules as inputs.          #
## --------------------------------------------------------------------------------------------- ##
dependency "hetzner" {
  config_path  = "../../hetzner/post"
  skip_outputs = false
  mock_outputs = {
    nodes              = include.common.locals.mock_nodes_full
    controlplane_nodes = include.common.locals.mock_nodes_full
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

dependency "tailscale_post" {
  config_path  = "../../tailscale/post"
  skip_outputs = false
  mock_outputs = {
    node_ipv4 = include.common.locals.mock_tailscale_ipv4
    node_ipv6 = include.common.locals.mock_tailscale_ipv6
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

dependency "talos_pre" {
  config_path  = "../pre"
  skip_outputs = false
  mock_outputs = {
    machine_configurations = {
      mock-node = "mock-machine-config"
    }
    machine_secrets = {
      client_configuration = {
        ca_certificate     = "mock"
        client_certificate = "mock"
        client_key         = "mock"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = include.common.locals.mock_outputs_allowed_terraform_commands
  mock_outputs_merge_strategy_with_state  = include.common.locals.mock_outputs_merge_strategy_with_state
}

inputs = {
  enabled = try(values.enabled, true)
  config = {
    cluster_name       = try(values.config.cluster_name, "") != "" ? values.config.cluster_name : "mock-cluster"
    cluster_endpoint   = try(values.config.cluster_endpoint, "") != "" ? values.config.cluster_endpoint : try(values.config.cluster_url.apiserver, "mock-apiserver.local")
    dualstack          = try(values.config.dualstack, true)
    first_controlplane = try(values.config.first_controlplane, "") != "" ? values.config.first_controlplane : "mock-node"
  }
  machine_configurations = dependency.talos_pre.outputs.machine_configurations
  machine_secrets        = dependency.talos_pre.outputs.machine_secrets
  nodes                  = try(values.hetzner_enabled, true) ? try(dependency.hetzner.outputs.nodes, {}) : {}
  tailscale_ipv4         = try(values.hetzner_enabled, true) && try(values.tailscale_enabled, true) ? try(dependency.tailscale_post.outputs.node_ipv4, {}) : {}
  tailscale_ipv6         = try(values.hetzner_enabled, true) && try(values.tailscale_enabled, true) && try(values.config.dualstack, true) ? try(dependency.tailscale_post.outputs.node_ipv6, {}) : {}
}