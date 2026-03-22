## ============================================================================================= ##
# prod.stack.hcl --- Production stack                                                             #
#                                                                                                 #
# Infrastructure:  hetzner + tailscale + cloudflare + talos                                       #
# Applications:    core/apps --- each app is a separate unit                                      #
#                                                                                                 #
# Apply order (driven by dependency blocks in each module's terragrunt.hcl):                      #
#                                                                                                 #
#   talos/pre                                                                                     #
#     └─> hetzner/post                                                                            #
#           └─> tailscale/post                                                                    #
#                 └─> talos/post                                                                  #
#                       └─> cloudflare/post                                                       #
#                             └─> longhorn                                                        #
#                                   └─> reflector                                                 #
#                                   └─> cnpg                                                      #
#                                   └─> kube-prometheus-stack                                     #
#                                         └─> cert-manager                                        #
#                                                                                                 #
# Usage:                                                                                          #
#   make plan  ENV=prod                                                                           #
#   make apply ENV=prod                                                                           #
## ============================================================================================= ##
locals {
  v = read_terragrunt_config("${get_repo_root()}/${get_env("STACK_ENV", "dev")}.values.hcl").locals
  s = read_terragrunt_config(get_env("TERRAGRUNT_SECRETS", "${get_repo_root()}/secrets.hcl")).locals

  node_assignments = {
    for idx, node in local.v.infra.kubernetes.nodes : node.name => {
      node       = node
      idx        = idx
      arch       = [for a in local.v.infra.hetzner.assignments : a.architecture if alltrue([for k, v in a.selector : lookup(node, k, null) == v])][0]
      assignment = [for a in local.v.infra.hetzner.assignments : a if alltrue([for k, v in a.selector : lookup(node, k, null) == v])][0]
    }
    if local.v.infra.hetzner.enabled
  }
  node_locations = {
    for name, data in local.node_assignments : name => (
      data.assignment.strategy == "roundrobin"
      ? data.assignment.locations[length([
        for i, n in local.v.infra.kubernetes.nodes : i
        if alltrue([for k, v in data.assignment.selector : lookup(n, k, null) == v]) && i < data.idx
      ]) % length(data.assignment.locations)]
      : data.assignment.locations[0]
    )
  }
  hetzner_nodes = local.v.infra.hetzner.enabled ? [
    for name, data in local.node_assignments : merge(data.node, {
      arch        = data.arch
      location    = local.node_locations[name]
      image_id    = local.v.infra.hetzner.images[data.arch].id
      server_type = local.v.infra.hetzner.images[data.arch].code
    })
  ] : []
  first_controlplane = [for node in local.v.infra.kubernetes.nodes : node.name if node.role == "controlplane"][0]
}

## --------------------------------------------------------------------------------------------- ##
#  Root wiring: infra stack + manifests stack                                                     #
## --------------------------------------------------------------------------------------------- ##
stack "infra" {
  source = "./modules/infra"
  path   = "infra"
  values = {
    config = {
      hetzner = {
        enabled         = local.v.infra.hetzner.enabled
        assignments     = local.v.infra.hetzner.assignments
        firewall        = local.v.infra.hetzner.firewall
        images          = local.v.infra.hetzner.images
        nodes           = local.hetzner_nodes
        private_network = local.v.infra.hetzner.private_network
      }
      cloudflare = {
        enabled = local.v.infra.cloudflare.enabled
      }
      tailscale = {
        enabled = local.v.infra.tailscale.enabled
      }
      kubernetes = {
        cluster_name       = local.v.infra.kubernetes.cluster_name
        cluster_url        = local.v.infra.kubernetes.cluster_url
        first_controlplane = local.first_controlplane
        ipcfg              = local.v.infra.kubernetes.ipcfg
        nodes              = local.v.infra.kubernetes.nodes
      }
      talos = {
        dualstack = local.v.infra.talos.dualstack
        kubeprism = local.v.infra.talos.kubeprism
        kubespan  = local.v.infra.talos.kubespan
      }
    }
    secrets = {
      hetzner = {
        api_token = local.s.hetzner.api_token
      }
      tailscale = {
        auth_key      = local.s.tailscale.auth_key
        client_id     = local.s.tailscale.client_id
        client_secret = local.s.tailscale.client_secret
        tailnet       = local.s.tailscale.tailnet
      }
      cloudflare = {
        api_token = local.s.cloudflare.api_token
        zone_id   = local.s.cloudflare.zone_id
      }
    }
    versions = {
      cilium     = local.v.infra.versions.cilium
      kubernetes = local.v.infra.versions.kubernetes
      talos      = local.v.infra.versions.talos
    }
    rootvars = local.v.infra
  }
}

stack "manifests" {
  source = "./modules/manifests"
  path   = "manifests"
  values = {
    config = {
      dns_domain = local.v.infra.kubernetes.cluster_url.dns
    }
    secrets = {
      cloudflare = {
        api_token = local.s.cloudflare.api_token
      }
    }
    apps = local.v.apps
  }
}