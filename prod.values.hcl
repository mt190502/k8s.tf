## ============================================================================================= ##
#  prod.values.hcl --- Single source of truth for the entire stack                                #
#                                                                                                 #
#  Edit this file to configure your cluster.                                                      #
#  Secrets (API tokens, keys) live in secrets.hcl (SOPS encrypted).                               #
## ============================================================================================= ##
locals {
  ## ============================================================================================= ##
  #  Infra Section --- cluster settings, node definitions, Talos options, firewall rules, etc.      #
  ## ============================================================================================= ##
  infra = {
    ## --------------------------------------------------------------------------------------------- ##
    #  Cluster identity                                                                               #
    ## --------------------------------------------------------------------------------------------- ##
    cluster_name = "srv.mtaha.dev"
    cluster_url = {
      dns       = "mtaha.dev"         # base domain -> wildcard cert, hubble peer domain
      main      = "srv.mtaha.dev"     # LB / proxied A record
      apiserver = "k8s.srv.mtaha.dev" # controlplane endpoint
    }

    ## --------------------------------------------------------------------------------------------- ##
    # Networking --- pod & service CIDRs                                                              #
    ## --------------------------------------------------------------------------------------------- ##
    ipcfg = {
      pod = {
        ipv4 = "10.244.0.0/16"
        ipv6 = "2001:db8:42:0::/56"
      }
      service = {
        ipv4 = "10.96.0.0/12"
        ipv6 = "2001:db8:42:1::/112"
      }
    }

    ## --------------------------------------------------------------------------------------------- ##
    #  Nodes                                                                                          #
    #    role: controlplane | worker                                                                  #
    #    arch: amd64 | arm64                                                                          #
    #    provider:                                                                                    #
    #      type (e.g. hetzner, libvirt, etc.) -- used to look up provider-specific settings           #
    #      location (e.g. hetzner region) -- used to determine where to create the node               #
    ## --------------------------------------------------------------------------------------------- ##
    nodes = {
      masters = [
        { name = "m1", arch = "arm64", provider = { type = "hetzner", location = "hel1" }, taints = [] },
        { name = "m2", arch = "arm64", provider = { type = "hetzner", location = "nbg1" }, taints = [] },
        { name = "m3", arch = "arm64", provider = { type = "hetzner", location = "fsn1" }, taints = [] },
      ]
      workers = [
        { name = "w1", arch = "amd64", provider = { type = "hetzner", location = "hel1" }, taints = [] },
        { name = "w2", arch = "amd64", provider = { type = "hetzner", location = "nbg1" }, taints = [] },
        { name = "w3", arch = "amd64", provider = { type = "hetzner", location = "fsn1" }, taints = [] },
      ]
    }

    ## --------------------------------------------------------------------------------------------- ##
    #  Provider options                                                                               #
    ## --------------------------------------------------------------------------------------------- ##
    cloudflare = {
      enabled = true
    }
    hetzner = {
      enabled = true
      image_ids = {
        amd64 = { id = "358263593", code = "cx33" }
        arm64 = { id = "358263592", code = "cax11" }
      }
      firewall = {
        enabled = true
        rules = [
          {
            short_name  = "https-in"
            description = "Allow HTTPS traffic"
            protocol    = "tcp"
            direction   = "in"
            port        = "443"
            source_ips  = ["0.0.0.0/0", "::/0"]
          },
          {
            short_name  = "https-in-udp"
            description = "Allow HTTPS/QUIC traffic"
            protocol    = "udp"
            direction   = "in"
            port        = "443"
            source_ips  = ["0.0.0.0/0", "::/0"]
          },
          {
            short_name  = "nodeport-tcp"
            description = "Allow Kubernetes NodePort TCP range"
            protocol    = "tcp"
            direction   = "in"
            port        = "30000-32767"
            source_ips  = ["0.0.0.0/0", "::/0"]
          },
          {
            short_name  = "nodeport-udp"
            description = "Allow Kubernetes NodePort UDP range"
            protocol    = "udp"
            direction   = "in"
            port        = "30000-32767"
            source_ips  = ["0.0.0.0/0", "::/0"]
          },
          {
            short_name  = "tailscale"
            description = "Allow Tailscale peer connectivity bootstrap"
            protocol    = "udp"
            direction   = "in"
            port        = "41641"
            source_ips  = ["0.0.0.0/0", "::/0"]
          },
          {
            short_name  = "wireguard"
            description = "Allow pod2pod WireGuard traffic",
            protocol    = "udp",
            direction   = "in",
            port        = "51871",
            source_ips  = ["0.0.0.0/0", "::/0"]
          },
          {
            short_name  = "cilium-vxlan"
            description = "Allow Cilium VXLAN tunnel traffic",
            protocol    = "udp",
            direction   = "in",
            port        = "8472",
            source_ips  = ["0.0.0.0/0", "::/0"]
          }
        ]
      }
    }
    tailscale = {
      enabled = true
    }
    talos = {
      dualstack = true
      kubespan  = false
      kubeprism = true
    }

    ## --------------------------------------------------------------------------------------------- ##
    #  Versions                                                                                       #
    ## --------------------------------------------------------------------------------------------- ##
    versions = {
      talos      = "v1.12.4"
      kubernetes = "v1.35.1"
      cilium     = "1.19.1"
    }
  }

  # ===========================================================================
  # Applications --- set enabled = false to skip deploying an app
  # ===========================================================================
  apps = {
    longhorn = {
      enabled = true
      version = "1.11.0"
    }
    reflector = {
      enabled = true
      version = "10.0.10"
    }
    kube_prometheus_stack = {
      enabled = true
      version = "82.1.0"
    }
    cnpg = {
      enabled = true
      version = "0.27.1"
    }
    cert_manager = {
      enabled                        = true
      version                        = "v1.19.3"
      acme_email                     = "mt190502@mtaha.dev"
      dns_domain                     = local.infra.cluster_url.dns
      wildcard_reflection_namespaces = ["adguard-home", "radicale"]
    }
    tests = {
      enabled = true
      config  = {
        domain = local.infra.cluster_url.dns
      }
    }
  }
}
