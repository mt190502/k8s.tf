## ============================================================================================= ##
#  modules/infra/terragrunt.stack.hcl --- Infrastructure sub-stack                                #
## ============================================================================================= ##
locals {
  config   = try(values.config, {})
  secrets  = try(values.secrets, {})
  versions = try(values.versions, {})
  units    = try(values.units, {})
}

unit "talos_pre" {
  source = "./talos/pre"
  path   = "talos/pre"
  values = {
    enabled = true
    config = {
      cluster_name = try(local.config.cluster_name, "")
      cluster_url  = try(local.config.cluster_url, null)
      dualstack    = try(local.config.dualstack, true)
      ipcfg        = try(local.config.ipcfg, null)
      kubeprism    = try(local.config.kubeprism, true)
      kubespan     = try(local.config.kubespan, false)
      nodes        = try(local.config.nodes, {})
    }
    secrets = {
      auth_key = try(local.secrets.tailscale.auth_key, "")
    }
    versions = {
      cilium     = try(local.versions.cilium, "")
      kubernetes = try(local.versions.kubernetes, "")
      talos      = try(local.versions.talos, "")
    }
  }
}

unit "hetzner_post" {
  source = "./hetzner/post"
  path   = "hetzner/post"
  values = {
    enabled = try(local.units.hetzner.enabled, true)
    config = {
      cluster_name = try(local.config.cluster_name, "")
      dualstack    = try(local.config.dualstack, true)
      firewall     = try(local.config.firewall, null)
      image_ids    = try(local.config.image_ids, null)
      nodes        = can(local.config.nodes) ? values(local.config.nodes) : []
    }
    secrets = {
      api_token = try(local.secrets.hetzner.api_token, "")
    }
  }
}

unit "tailscale_post" {
  source = "./tailscale/post"
  path   = "tailscale/post"
  values = {
    enabled = try(local.units.tailscale.enabled, true)
    config = {
      dualstack = try(local.config.dualstack, true)
    }
    secrets = {
      auth_key      = try(local.secrets.tailscale.auth_key, "")
      client_id     = try(local.secrets.tailscale.client_id, "")
      client_secret = try(local.secrets.tailscale.client_secret, "")
      tailnet       = try(local.secrets.tailscale.tailnet, "")
    }
  }
}

unit "talos_post" {
  source = "./talos/post"
  path   = "talos/post"
  values = {
    enabled = true
    config = {
      cluster_name       = try(local.config.cluster_name, "")
      cluster_endpoint   = try(local.config.cluster_url.apiserver, "")
      dualstack          = try(local.config.dualstack, true)
      first_controlplane = try(local.config.first_controlplane, "")
    }
    #~ TODO: Remove this hardcoded options
    hetzner_enabled   = try(local.units.hetzner.enabled, true)
    tailscale_enabled = try(local.units.tailscale.enabled, true)
  }
}

unit "cloudflare_post" {
  source = "./cloudflare/post"
  path   = "cloudflare/post"
  values = {
    enabled = try(local.units.cloudflare.enabled, true)
    config = {
      cluster_url = try(local.config.cluster_url, null)
      dualstack   = try(local.config.dualstack, true)
    }
    secrets = {
      api_token = try(local.secrets.cloudflare.api_token, "")
      zone_id   = try(local.secrets.cloudflare.zone_id, "")
    }
  }
}