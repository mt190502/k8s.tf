## ============================================================================================= ##
#  modules/infra/terragrunt.stack.hcl --- Infrastructure sub-stack                                #
#                                                                                                 #
#  Units: talos/pre -> [provider]/post -> tailscale/post -> talos/post -> cloudflare/post         #
#                                                                                                 #
#  Provider-specific node enrichment:                                                             #
#    - hetzner: adds arch, location, image_id, server_type via roundrobin assignment              #
#    - libvirt: adds pool, volume_size, memory, vcpu (future)                                     #
## ============================================================================================= ##
locals {
  #~ Provider flags
  hetzner_enabled = try(values.infra.hetzner.enabled, false)
  libvirt_enabled = try(values.infra.libvirt.enabled, false)

  #~ Hetzner node enrichment (roundrobin location assignment)
  hetzner_node_assignments = {
    for idx, node in try(values.infra.kubernetes.nodes, []) : node.name => {
      node       = node
      idx        = idx
      arch       = try([for a in values.infra.hetzner.assignments : a.architecture if alltrue([for k, v in a.selector : lookup(node, k, null) == v])][0], "amd64")
      assignment = try([for a in values.infra.hetzner.assignments : a if alltrue([for k, v in a.selector : lookup(node, k, null) == v])][0], null)
    }
    if local.hetzner_enabled
  }

  #~ Hetzner node locations (roundrobin location assignment)
  hetzner_node_locations = {
    for name, data in local.hetzner_node_assignments : name => (
      data.assignment != null && data.assignment.strategy == "roundrobin"
      ? data.assignment.locations[length([
        for i, n in values.infra.kubernetes.nodes : i
        if try(alltrue([for k, v in data.assignment.selector : lookup(n, k, null) == v]), false) && i < data.idx
      ]) % length(data.assignment.locations)]
      : try(data.assignment.locations[0], "fsn1")
    )
  }

  #~ Hetzner nodes (roundrobin location assignment)
  hetzner_nodes = local.hetzner_enabled ? [
    for name, data in local.hetzner_node_assignments : merge(data.node, {
      arch        = data.arch
      location    = local.hetzner_node_locations[name]
      image_id    = try(values.infra.hetzner.images[data.arch].id, "")
      server_type = try(values.infra.hetzner.images[data.arch].code, "")
    })
  ] : []

  # Libvirt node enrichment (placeholder)
  libvirt_nodes = local.libvirt_enabled ? [
    for node in try(values.infra.kubernetes.nodes, []) : merge(node, {
      arch        = try(node.arch, "amd64")
      pool        = try(values.infra.libvirt.pool, "default")
      volume_size = try(values.infra.libvirt.volume_size, "20G")
      memory      = try(node.memory, try(values.infra.libvirt.memory, 2048))
      vcpu        = try(node.vcpu, try(values.infra.libvirt.vcpu, 2))
    })
  ] : []

  # Active provider's enriched nodes (priority: hetzner > libvirt > raw)
  nodes = (
    local.hetzner_enabled ? local.hetzner_nodes :
    local.libvirt_enabled ? local.libvirt_nodes :
    [for node in try(values.infra.kubernetes.nodes, []) : merge(node, { arch = try(node.arch, "amd64") })]
  )

  # First controlplane (for talos_post bootstrap)
  first_controlplane = try([for node in values.infra.kubernetes.nodes : node.name if node.role == "controlplane"][0], "")
}

## --------------------------------------------------------------------------------------------- ##
#  Talos Pre - Machine secrets and per-node config generation                                     #
## --------------------------------------------------------------------------------------------- ##
unit "talos_pre" {
  source = "./talos/pre"
  path   = "talos/pre"
  values = {
    enabled = true
    config = {
      cluster_name      = try(values.infra.kubernetes.cluster_name, "")
      cluster_url       = try(values.infra.kubernetes.cluster_url, null)
      dualstack         = try(values.infra.talos.dualstack, true)
      ipcfg             = try(values.infra.kubernetes.ipcfg, null)
      kubeprism         = try(values.infra.talos.kubeprism, true)
      kubespan          = try(values.infra.talos.kubespan, false)
      nodes             = local.nodes
      overwrite_dns     = try(values.infra.kubernetes.overwrite_dns, false)
      preferred_gateway = try(values.infra.kubernetes.preferred_gateway, "cilium")
      private_network   = try(values.infra.hetzner.private_network, null)
    }
    secrets = {
      auth_key = try(values.secrets.tailscale.auth_key, "")
    }
    versions = try(values.infra.versions, {})
    rootvars = try(values.infra, {})
  }
}

## --------------------------------------------------------------------------------------------- ##
#  Provider: Hetzner - Cloud VM provisioning                                                      #
## --------------------------------------------------------------------------------------------- ##
unit "hetzner_post" {
  source = "./hetzner/post"
  path   = "hetzner/post"
  values = {
    enabled = local.hetzner_enabled
    config = {
      assignments     = try(values.infra.hetzner.assignments, [])
      cluster_name    = try(values.infra.kubernetes.cluster_name, "")
      dualstack       = try(values.infra.talos.dualstack, true)
      firewall        = try(values.infra.hetzner.firewall, null)
      images          = try(values.infra.hetzner.images, null)
      nodes           = local.hetzner_nodes
      private_network = try(values.infra.hetzner.private_network, null)
    }
    secrets = {
      api_token = try(values.secrets.hetzner.api_token, "")
    }
    rootvars = try(values.infra, {})
  }
}

## --------------------------------------------------------------------------------------------- ##
#  Provider: Libvirt - Local VM provisioning (placeholder)                                        #
## --------------------------------------------------------------------------------------------- ##
# unit "libvirt_post" {
#   TODO: Implement Libvirt stage
# }

## --------------------------------------------------------------------------------------------- ##
#  Network: Tailscale - VPN mesh                                                                  #
## --------------------------------------------------------------------------------------------- ##
unit "tailscale_post" {
  source = "./tailscale/post"
  path   = "tailscale/post"
  values = {
    enabled = try(values.infra.tailscale.enabled, true)
    config = {
      dualstack = try(values.infra.talos.dualstack, true)
    }
    secrets = {
      client_id     = try(values.secrets.tailscale.client_id, "")
      client_secret = try(values.secrets.tailscale.client_secret, "")
      tailnet       = try(values.secrets.tailscale.tailnet, "")
    }
    rootvars = try(values.infra, {})
  }
}

## --------------------------------------------------------------------------------------------- ##
#  Talos Post - Cluster bootstrap                                                                 #
## --------------------------------------------------------------------------------------------- ##
unit "talos_post" {
  source = "./talos/post"
  path   = "talos/post"
  values = {
    enabled = true
    config = {
      cluster_name       = try(values.infra.kubernetes.cluster_name, "")
      cluster_endpoint   = try(values.infra.kubernetes.cluster_url.apiserver, "")
      dualstack          = try(values.infra.talos.dualstack, true)
      first_controlplane = local.first_controlplane
    }
    rootvars = try(values.infra, {})
  }
}

## --------------------------------------------------------------------------------------------- ##
#  Network: Cloudflare - DNS management                                                           #
## --------------------------------------------------------------------------------------------- ##
unit "cloudflare_post" {
  source = "./cloudflare/post"
  path   = "cloudflare/post"
  values = {
    enabled = try(values.infra.cloudflare.enabled, true)
    config = {
      cluster_url = try(values.infra.kubernetes.cluster_url, null)
      dualstack   = try(values.infra.talos.dualstack, true)
    }
    secrets = {
      api_token = try(values.secrets.cloudflare.api_token, "")
      zone_id   = try(values.secrets.cloudflare.zone_id, "")
    }
    rootvars = try(values.infra, {})
  }
}