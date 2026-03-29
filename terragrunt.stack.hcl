## ============================================================================================= ##
# terragrunt.stack.hcl --- Root stack definition                                                  #
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
  v         = read_terragrunt_config("${get_repo_root()}/${get_env("STACK_ENV", "dev")}.values.hcl").locals
  s         = read_terragrunt_config(get_env("TERRAGRUNT_SECRETS", "${get_repo_root()}/secrets.hcl")).locals
  c         = read_terragrunt_config("${get_repo_root()}/modules/common.hcl")
  infra     = try(local.v.infra, null) != null ? local.v.infra : local.c.locals.mock_infra
  manifests = try(local.v.manifests, {})
  node_assignments = {
    for idx, node in local.infra.kubernetes.nodes : node.name => {
      node       = node
      idx        = idx
      arch       = [for a in local.infra.hetzner.assignments : a.architecture if alltrue([for k, v in a.selector : lookup(node, k, null) == v])][0]
      assignment = [for a in local.infra.hetzner.assignments : a if alltrue([for k, v in a.selector : lookup(node, k, null) == v])][0]
    }
    if local.infra.hetzner.enabled
  }
  node_locations = {
    for name, data in local.node_assignments : name => (
      data.assignment.strategy == "roundrobin"
      ? data.assignment.locations[length([
        for i, n in local.infra.kubernetes.nodes : i
        if alltrue([for k, v in data.assignment.selector : lookup(n, k, null) == v]) && i < data.idx
      ]) % length(data.assignment.locations)]
      : data.assignment.locations[0]
    )
  }
  hetzner_nodes = local.infra.hetzner.enabled ? [
    for name, data in local.node_assignments : merge(data.node, {
      arch        = data.arch
      location    = local.node_locations[name]
      image_id    = local.infra.hetzner.images[data.arch].id
      server_type = local.infra.hetzner.images[data.arch].code
    })
  ] : []
  first_controlplane = [for node in local.infra.kubernetes.nodes : node.name if node.role == "controlplane"][0]
  controlplane_count = length([for node in local.infra.kubernetes.nodes : node if node.role == "controlplane"])
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
        enabled         = local.infra.hetzner.enabled
        assignments     = local.infra.hetzner.assignments
        firewall        = local.infra.hetzner.firewall
        images          = local.infra.hetzner.images
        nodes           = local.hetzner_nodes
        private_network = local.infra.hetzner.private_network
      }
      cloudflare = {
        enabled = local.infra.cloudflare.enabled
      }
      tailscale = {
        enabled = local.infra.tailscale.enabled
      }
      kubernetes = {
        cluster_name       = local.infra.kubernetes.cluster_name
        cluster_url        = local.infra.kubernetes.cluster_url
        first_controlplane = local.first_controlplane
        ipcfg              = local.infra.kubernetes.ipcfg
        nodes              = local.infra.kubernetes.nodes
        preferred_gateway  = local.infra.kubernetes.preferred_gateway
      }
      talos = {
        dualstack = local.infra.talos.dualstack
        kubeprism = local.infra.talos.kubeprism
        kubespan  = local.infra.talos.kubespan
      }
    }
    secrets = {
      hetzner = {
        api_token = try(local.s.infra.hetzner.api_token, "")
      }
      tailscale = {
        auth_key      = try(local.s.infra.tailscale.auth_key, "")
        client_id     = try(local.s.infra.tailscale.client_id, "")
        client_secret = try(local.s.infra.tailscale.client_secret, "")
        tailnet       = try(local.s.infra.tailscale.tailnet, "")
      }
      cloudflare = {
        api_token = try(local.s.infra.cloudflare.api_token, "")
        zone_id   = try(local.s.infra.cloudflare.zone_id, "")
      }
    }
    versions = {
      cilium     = local.infra.versions.cilium
      kubernetes = local.infra.versions.kubernetes
      talos      = local.infra.versions.talos
    }
    rootvars = local.infra
  }
}

stack "manifests" {
  source = "./modules/manifests"
  path   = "manifests"
  values = {
    core = {
      cert_manager = merge(
        try(local.manifests.core.cert_manager, {}),
        {
          config = merge(
            try(local.manifests.core.cert_manager.config, {}),
            { dns_domain = local.infra.kubernetes.cluster_url.dns }
          )
          secrets = {
            api_token = try(local.s.infra.cloudflare.api_token, "")
          }
        }
      )
      cnpg = merge(
        try(local.manifests.core.cnpg, {}),
        {
          config = merge(
            try(local.manifests.core.cnpg.config, {}),
            { controlplane_count = local.controlplane_count }
          )
        }
      )
      kube_prometheus_stack = try(local.manifests.core.kube_prometheus_stack, {})
      longhorn              = try(local.manifests.core.longhorn, {})
      psmdb_operator        = try(local.manifests.core.psmdb_operator, {})
      reflector             = try(local.manifests.core.reflector, {})
      tailscale_operator = merge(
        try(local.manifests.core.tailscale_operator, {}),
        {
          config = merge(
            try(local.manifests.core.tailscale_operator.config, {}),
            {
              subnet_router_advertised_cidrs = concat(
                [local.infra.kubernetes.ipcfg.service.ipv4],
                local.infra.talos.dualstack ? [local.infra.kubernetes.ipcfg.service.ipv6] : []
              )
            }
          )
          secrets = {
            auth_key      = try(local.s.infra.tailscale.auth_key, "")
            client_id     = try(local.s.infra.tailscale.client_id, "")
            client_secret = try(local.s.infra.tailscale.client_secret, "")
          }
        }
      )
      traefik = merge(
        try(local.manifests.core.traefik, {}),
        {
          enabled = local.infra.kubernetes.preferred_gateway == "traefik"
          config = merge(
            try(local.manifests.core.traefik.config, {}),
            { gateway_name = "traefik-gateway" }
          )
        }
      )
      tests = try(local.manifests.core.tests, { enabled = false })
    }
    apps = {
      nightscout = merge(
        try(local.manifests.apps.nightscout, {}),
        {
          secrets = {
            api_secret = try(local.s.manifests.apps.nightscout.api_secret, "")
          }
        }
      )
      redmine = merge(
        try(local.manifests.apps.redmine, {}),
        {
          secrets = {
            basic_auth = try(local.s.manifests.apps.redmine.basic_auth, try(local.s.manifests.apps.misc.basic_auth, { username = "", password_hash = "" }))
            pg = {
              password = try(local.s.manifests.apps.redmine.pg.password, "")
            }
          }
        }
      )
    }
    rootvars = {
      cluster_url       = local.infra.kubernetes.cluster_url
      preferred_gateway = local.infra.kubernetes.preferred_gateway
    }
  }
}