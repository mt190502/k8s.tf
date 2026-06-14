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
      overwrite_dns     = false
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
      talos = "v1.13.4"
      # renovate: datasource=github-releases depName=siderolabs/kubelet
      kubernetes = "v1.36.2"
      # renovate: datasource=github-releases depName=cilium/cilium
      cilium = "1.19.4"
      # renovate: datasource=github-releases depName=kubernetes-sigs/metrics-server
      metrics_server = "v0.8.1"
      # renovate: datasource=github-releases depName=kubernetes-sigs/gateway-api
      gateway_api = "v1.5.1"
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
      }
      gotify = {
        enabled = true
        config = {
          hostname = "ntfy"
        }
      }
      slimserve = {
        enabled = true
        config = {
          dirs     = "/data"
          hostname = "files"
          persistence = {
            enabled      = true
            bucket_name  = "files"
            s3_endpoint  = "http://100.102.30.2:3900"
            s3_region    = "us-east-1"
            storage_size = "1T"
          }
        }
      }
      syncstorage_rs = {
        enabled = true
        config = {
          hostname = "ffsync"
          pg = {
            replicas     = 1
            storage_size = "1Gi"
          }
        }
      }
      miniflux = {
        enabled = true
        config = {
          env = {
            CLEANUP_ARCHIVE_READ_DAYS   = "30"
            CLEANUP_ARCHIVE_UNREAD_DAYS = "30"
          }
          hostname = "rss"
          pg = {
            replicas     = 1
            storage_size = "1Gi"
          }
        }
      }
      nightscout = {
        enabled = true
        config = {
          env = {
            ALARM_HIGH         = "off"
            ALARM_LOW          = "off"
            ALARM_URGENT_HIGH  = "off"
            ALARM_URGENT_LOW   = "off"
            AUTH_DEFAULT_ROLES = "readable"
            BG_HIGH            = "200"
            BG_LOW             = "60"
            BG_TARGET_BOTTOM   = "70"
            BG_TARGET_TOP      = "180"
            CUSTOM_TITLE       = "Taha's CGM"
            ENABLE             = "careportal iob cob cors rawbg"
            HOSTNAME           = "::"
            INSECURE_USE_HTTP  = "true"
            NODE_ENV           = "production"
            SHOW_PLUGINS       = "careportal iob cob cors dbsize basal"
            THEME              = "colorblindfriendly"
            TIME_FORMAT        = "24"
            TZ                 = "Europe/Istanbul"
          }
          hostname = "t1d"
          mongo = {
            replicas     = 2
            storage_size = "2Gi"
          }
        }
      }
      radicale = {
        enabled = true
        config = {
          hostname = "dav"
        }
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
      }
    }
    core = {
      atlantis = {
        enabled = true
        config = {
          aws_s3_region   = "us-east-1"
          basic_auth      = true
          github_app_slug = "m-taha-s-atlantis-bot"
          hostname        = "atlantis"
          repo_allowlist  = "github.com/mt190502/k8s.tf"
        }
      }
      cert_manager = {
        enabled = true
        config = {
          acme_email = "mt190502@mtaha.dev"
        }
      }
      cnpg = {
        enabled = true
      }
      descheduler = {
        enabled = true
        config = {
          descheduling_interval = "5m"
          replicas              = 2
        }
      }
      dnsutils = {
        enabled = true
      }
      kube_prometheus_stack = {
        enabled = true
        config = {
          gotify_enabled = true
          hostname       = "dash"
          storage_size   = "1Gi"
        }
      }
      loki = {
        config = {
          s3               = "loki"
          endpoint         = "http://100.102.30.2:3900"
          region           = "us-east-1"
          force_path_style = true
        }
      }
      longhorn = {
        enabled = true
      }
      s3_csi = {
        enabled = true
        config = {
          endpoint = "http://100.102.30.2:3900"
          region   = "us-east-1"
        }
      }
      mongodb_community_operator = {
        enabled = true
      }
      psmdb_operator = {
        enabled = false
      }
      reflector = {
        enabled = true
        config = {
          wildcard_reflection_namespaces = ["radicale"]
        }
      }
      tailscale_operator = {
        enabled = true
      }
      tests = {
        enabled = false
      }
    }
  }
}
