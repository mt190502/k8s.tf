## ============================================================================================= ##
# prod.stack.hcl --- Production stack                                                             #
#                                                                                                 #
# Infrastructure:  hetzner + tailscale + cloudflare + talos                                       #
# Applications:    core/apps --- each app is a separate unit                                      #
#                                                                                                 #
# Apply order (driven by dependency blocks in each module's terragrunt.hcl):                      #
#                                                                                                 #
#   talos/pre                                                                                     #
#     └─► hetzner/post                                                                            #
#           └─► tailscale/post                                                                    #
#                 └─► talos/post                                                                  #
#                       └─► cloudflare/post                                                       #
#                             └─► longhorn                                                        #
#                                   └─► reflector                                                 #
#                                   └─► cnpg                                                      #
#                                   └─► kube-prometheus-stack                                     #
#                                         └─► cert-manager                                        #
#                                                                                                 #
# Usage:                                                                                          #
#   make plan   ENV=prod                                                                          #
#   make apply  ENV=prod                                                                          #
## ============================================================================================= ##
locals {
  v = read_terragrunt_config("${get_repo_root()}/prod.values.hcl").locals
  s = read_terragrunt_config(get_env("TERRAGRUNT_SECRETS", "${get_repo_root()}/secrets.hcl")).locals
}

## --------------------------------------------------------------------------------------------- ##
#  Root wiring: infra stack + manifests stack                                                     #
## --------------------------------------------------------------------------------------------- ##
stack "infra" {
  source = "./modules/infra"
  path   = "infra"
  values = {
    config = {
      cluster_name       = local.v.infra.cluster_name
      cluster_url        = local.v.infra.cluster_url
      dualstack          = local.v.infra.talos.dualstack
      firewall           = local.v.infra.hetzner.firewall
      first_controlplane = local.v.infra.nodes.masters[0].name
      image_ids          = local.v.infra.hetzner.image_ids
      ipcfg              = local.v.infra.ipcfg
      kubeprism          = local.v.infra.talos.kubeprism
      kubespan           = local.v.infra.talos.kubespan
      nodes = merge(
        {
          for node in local.v.infra.nodes.masters : node.name => {
            name     = node.name
            role     = "controlplane"
            type     = node.arch
            location = node.provider.type == "hetzner" ? node.provider.location : "local"
            taints   = node.taints
          }
        },
        {
          for node in local.v.infra.nodes.workers : node.name => {
            name     = node.name
            role     = "worker"
            type     = node.arch
            location = node.provider.type == "hetzner" ? node.provider.location : "local"
            taints   = node.taints
          }
        }
      )
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
    units = local.v.infra
  }
}

stack "manifests" {
  source = "./modules/manifests"
  path   = "manifests"
  values = {
    secrets = {
      cloudflare = {
        api_token = local.s.cloudflare.api_token
      }
    }
    apps = local.v.apps
  }
}