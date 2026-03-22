## ============================================================================================= ##
#  modules/infra/terragrunt.stack.hcl --- Infrastructure sub-stack                                #
## ============================================================================================= ##
locals {
  c = try(values.config, {})
  s = try(values.secrets, {})
  v = try(values.versions, {})
  r = try(values.rootvars, {})
}

unit "talos_pre" {
  source = "./talos/pre"
  path   = "talos/pre"
  values = {
    enabled = true
    config = {
      cluster_name = try(local.c.kubernetes.cluster_name, "")
      cluster_url  = try(local.c.kubernetes.cluster_url, null)
      dualstack    = try(local.c.talos.dualstack, true)
      ipcfg        = try(local.c.kubernetes.ipcfg, null)
      kubeprism    = try(local.c.talos.kubeprism, true)
      kubespan     = try(local.c.talos.kubespan, false)
      nodes        = try(local.c.kubernetes.nodes, [])
    }
    secrets = {
      auth_key = try(local.s.tailscale.auth_key, "")
    }
    versions = {
      cilium     = try(local.v.cilium, "")
      kubernetes = try(local.v.kubernetes, "")
      talos      = try(local.v.talos, "")
    }
    rootvars = local.r
  }
}

unit "hetzner_post" {
  source = "./hetzner/post"
  path   = "hetzner/post"
  values = {
    enabled = try(local.c.hetzner.enabled, true)
    config = {
      assignments     = try(local.c.hetzner.assignments, [])
      cluster_name    = try(local.c.kubernetes.cluster_name, "")
      dualstack       = try(local.c.talos.dualstack, true)
      firewall        = try(local.c.hetzner.firewall, null)
      images          = try(local.c.hetzner.images, null)
      nodes           = try(local.c.hetzner.nodes, [])
      private_network = try(local.c.hetzner.private_network, null)
    }
    secrets = {
      api_token = try(local.s.hetzner.api_token, "")
    }
    rootvars = local.r
  }
}

unit "tailscale_post" {
  source = "./tailscale/post"
  path   = "tailscale/post"
  values = {
    enabled = try(local.c.tailscale.enabled, true)
    config = {
      dualstack = try(local.c.talos.dualstack, true)
    }
    secrets = {
      auth_key      = try(local.s.tailscale.auth_key, "")
      client_id     = try(local.s.tailscale.client_id, "")
      client_secret = try(local.s.tailscale.client_secret, "")
      tailnet       = try(local.s.tailscale.tailnet, "")
    }
    rootvars = local.r
  }
}

unit "talos_post" {
  source = "./talos/post"
  path   = "talos/post"
  values = {
    enabled = true
    config = {
      cluster_name       = try(local.c.kubernetes.cluster_name, "")
      cluster_endpoint   = try(local.c.kubernetes.cluster_url.apiserver, "")
      dualstack          = try(local.c.talos.dualstack, true)
      first_controlplane = try(local.c.kubernetes.first_controlplane, "")
    }
    rootvars = local.r
  }
}

unit "cloudflare_post" {
  source = "./cloudflare/post"
  path   = "cloudflare/post"
  values = {
    enabled = try(local.c.cloudflare.enabled, true)
    config = {
      cluster_url = try(local.c.kubernetes.cluster_url, null)
      dualstack   = try(local.c.talos.dualstack, true)
    }
    secrets = {
      api_token = try(local.s.cloudflare.api_token, "")
      zone_id   = try(local.s.cloudflare.zone_id, "")
    }
    rootvars = local.r
  }
}