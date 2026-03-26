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
    kubernetes = {
      cluster_name = "srv.mtaha.dev"
      cluster_url = {
        dns       = "mtaha.dev"         # base domain -> wildcard cert, hubble peer domain
        main      = "srv.mtaha.dev"     # LB / proxied A record
        apiserver = "k8s.srv.mtaha.dev" # controlplane endpoint
      }
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
      nodes = [
        { name = "m1", role = "controlplane", taints = [] },
        { name = "m2", role = "controlplane", taints = [] },
        { name = "m3", role = "controlplane", taints = [] },
        { name = "w1", role = "worker", taints = [] },
        { name = "w2", role = "worker", taints = [] },
        { name = "w3", role = "worker", taints = [] },
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
      assignments = [
        {
          selector     = { role = "controlplane" }
          architecture = "arm64"
          locations    = ["hel1", "nbg1", "fsn1"]
          strategy     = "roundrobin"
        },
        {
          selector     = { role = "worker" }
          architecture = "amd64"
          locations    = ["hel1", "nbg1", "fsn1"]
          strategy     = "roundrobin"
        }
      ]
      firewall = {
        enabled = true
        rules = [
          {
            short_name  = "https"
            description = "Allow HTTPS traffic"
            protocol    = "tcp"
            direction   = "in"
            port        = "443"
            source_ips  = ["0.0.0.0/0", "::/0"]
          },
          {
            short_name  = "https-quic"
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
          }
        ]
      }
      images = {
        amd64 = { id = "368740932", code = "cx33" }
        arm64 = { id = "368740925", code = "cax11" }
      }
      private_network = {
        enabled = true
        cidr    = "10.0.0.0/16"
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
      talos      = "v1.12.6"
      kubernetes = "v1.35.2"
      cilium     = "1.19.1"
    }
  }

  ## ============================================================================================= ##
  #  Applications --- set enabled = false to skip deploying an app                                  #
  ## ============================================================================================= ##
  apps = {
    cert_manager = {
      enabled    = true
      version    = "v1.19.3"
      acme_email = "mt190502@mtaha.dev"
    }
    cnpg = {
      enabled = true
      version = "0.27.1"
    }
    kube_prometheus_stack = {
      enabled = true
      version = "82.1.0"
    }
    longhorn = {
      enabled = true
      version = "1.11.0"
    }
    reflector = {
      enabled                        = true
      version                        = "10.0.10"
      wildcard_reflection_namespaces = ["adguard-home", "radicale"]
    }
    tailscale_operator = {
      enabled = true
      version = "1.94.2"
    }
    tests = {
      enabled = false
    }
  }
}
