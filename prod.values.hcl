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
      preferred_gateway = "traefik"
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
      # renovate: datasource=github-releases depName=siderolabs/talos
      talos = "v1.12.6"
      # renovate: datasource=github-releases depName=kubernetes/kubernetes
      kubernetes = "v1.35.2"
      # renovate: datasource=github-releases depName=cilium/cilium
      cilium = "1.19.1"
    }
  }

  ## ============================================================================================= ##
  #  Applications --- set enabled = false to skip deploying an app                                  #
  ## ============================================================================================= ##
  manifests = {
    apps = {
      anki = {
        enabled = true
        config = {
          hostname = "anki"
        }
        # renovate: datasource=docker depName=ghcr.io/mt190502/docker-anki-sync-server
        version = "25.09.2"
      }
      miniflux = {
        enabled = true
        config = {
          hostname = "rss"
          pg = {
            replicas     = 1
            storage_size = "1Gi"
          }
        }
        # renovate: datasource=docker depName=miniflux/miniflux
        version = "2.2.18"
      }
      nightscout = {
        enabled = true
        config = {
          env = {
            ALARM_URGENT_HIGH  = "off"
            ALARM_HIGH         = "off"
            ALARM_LOW          = "off"
            ALARM_URGENT_LOW   = "off"
            BG_LOW             = "60"
            BG_HIGH            = "200"
            BG_TARGET_TOP      = "180"
            BG_TARGET_BOTTOM   = "70"
            CUSTOM_TITLE       = "Taha's CGM"
            THEME              = "colorblindfriendly"
            TIME_FORMAT        = "24"
            SHOW_PLUGINS       = "careportal iob cob cors dbsize basal"
            TZ                 = "Europe/Istanbul"
            AUTH_DEFAULT_ROLES = "readable"
            ENABLE             = "careportal iob cob cors rawbg"
            NODE_ENV           = "production"
            INSECURE_USE_HTTP  = "true"
          }
          hostname = "t1d"
          mongo = {
            replicas     = 3
            storage_size = "2Gi"
          }
        }
        # renovate: datasource=docker depName=nightscout/cgm-remote-monitor
        version = "15.0.3"
      }
      radicale = {
        enabled = true
        config = {
          hostname = "dav"
        }
        # renovate: datasource=docker depName=tomsquest/docker-radicale
        version = "3.6.1.0"
      }
      redmine = {
        enabled = true
        config = {
          basic_auth = true
          hostname   = "red"
          pg = {
            replicas     = 3
            storage_size = "1Gi"
          }
        }
        # renovate: datasource=docker depName=redmine
        version = "6.1.2"
      }
      umami = {
        enabled = true
        config = {
          hostname = "umami"
          pg = {
            replicas     = 2
            storage_size = "1Gi"
          }
        }
        # renovate: datasource=docker depName=ghcr.io/umami-software/umami
        version = "3.0.3"
      }
    }
    core = {
      cert_manager = {
        enabled = true
        config = {
          acme_email = "mt190502@mtaha.dev"
        }
        # renovate: datasource=helm depName=cert-manager registryUrl=https://charts.jetstack.io
        version = "v1.20.1"
      }
      cnpg = {
        enabled = true
        # renovate: datasource=helm depName=cloudnative-pg registryUrl=https://cloudnative-pg.github.io/charts
        version = "0.28.0"
      }
      kube_prometheus_stack = {
        enabled = true
        # renovate: datasource=helm depName=kube-prometheus-stack registryUrl=https://prometheus-community.github.io/helm-charts
        version = "82.16.1"
      }
      longhorn = {
        enabled = true
        # renovate: datasource=helm depName=longhorn registryUrl=https://charts.longhorn.io
        version = "1.11.1"
      }
      psmdb_operator = {
        enabled = true
        # renovate: datasource=helm depName=psmdb-operator registryUrl=https://percona.github.io/percona-helm-charts
        version = "1.22.0"
      }
      reflector = {
        enabled = true
        config = {
          wildcard_reflection_namespaces = ["radicale"]
        }
        # renovate: datasource=helm depName=reflector registryUrl=https://emberstack.github.io/helm-charts
        version = "10.0.26"
      }
      tailscale_operator = {
        enabled = true
        # renovate: datasource=helm depName=tailscale-operator registryUrl=https://pkgs.tailscale.com/helmcharts
        version = "1.94.2"
      }
      traefik = {
        versions = {
          # renovate: datasource=helm depName=traefik registryUrl=https://traefik.github.io/charts
          main = "39.0.7"
          # renovate: datasource=helm depName=traefik-crds registryUrl=https://traefik.github.io/charts
          crds = "1.16.0"
        }
      }
      tests = {
        enabled = false
      }
    }
  }
}
