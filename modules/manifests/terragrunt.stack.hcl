## ============================================================================================= ##
#  modules/manifests/terragrunt.stack.hcl --- Manifests sub-stack (core + apps)                   #
#                                                                                                 #
#  Receives from root stack:                                                                      #
#    values.manifests --- raw manifests config from prod.values.hcl                               #
#    values.secrets   --- raw secrets from secrets.hcl                                            #
#    values.infra     --- raw infra config (for rootvars derivation)                              #
#                                                                                                 #
#  Computes internally:                                                                           #
#    rootvars         --- derived values (cluster_url, preferred_gateway)                         #
#    app secrets      --- injected from values.secrets into each app unit                         #
#    core secrets     --- injected from values.secrets into core units (cert_manager, tailscale)  #
## ============================================================================================= ##
locals {
  # Raw inputs from root stack
  manifests = try(values.manifests, {})
  secrets   = try(values.secrets, {})
  infra     = try(values.infra, {})

  # Derived values for modules
  rootvars = {
    cluster_url       = try(local.infra.kubernetes.cluster_url, { dns = "mock.local" })
    preferred_gateway = try(local.infra.kubernetes.preferred_gateway, "cilium")
  }

  # Core module configs (with secrets injected)
  core = try(local.manifests.core, {})
  apps = try(local.manifests.apps, {})
}

## --------------------------------------------------------------------------------------------- ##
#  Core manifests units                                                                           #
## --------------------------------------------------------------------------------------------- ##
unit "atlantis" {
  source = "./core/atlantis"
  path   = "core/atlantis"
  values = {
    enabled = try(local.core.atlantis.enabled, false)
    config = merge(
      try(local.core.atlantis.config, {}),
      {
        domain            = local.rootvars.cluster_url.dns
        preferred_gateway = local.rootvars.preferred_gateway
        gateway_name      = try(local.core.traefik.config.gateway_name, "traefik-gateway")
        gateway_namespace = "traefik-system"
        port              = 80
      }
    )
    secrets = {
      app = {
        aws_access_key         = try(local.secrets.manifests.core.atlantis.aws_access_key, "")
        aws_s3_bucket          = try(local.secrets.manifests.core.atlantis.aws_s3_bucket, "")
        aws_s3_endpoint        = try(local.secrets.manifests.core.atlantis.aws_s3_endpoint, "")
        aws_secret_key         = try(local.secrets.manifests.core.atlantis.aws_secret_key, "")
        github_app_key         = try(local.secrets.manifests.core.atlantis.github_app_key, "")
        github_app_id          = try(local.secrets.manifests.core.atlantis.github_app_id, "")
        github_installation_id = try(local.secrets.manifests.core.atlantis.github_installation_id, "")
        sops_age_key           = try(local.secrets.manifests.core.atlantis.sops_age_key, "")
        tf_encryption_pass     = try(local.secrets.manifests.core.atlantis.tf_encryption_pass, "")
        webhook_secret         = try(local.secrets.manifests.core.atlantis.webhook_secret, "")
      }
      basic_auth = try(local.secrets.manifests.core.atlantis.basic_auth, try(local.secrets.manifests.apps.misc.basic_auth, { username = "", password_hash = "" }))
    }
  }
}

unit "cert_manager" {
  source = "./core/cert-manager"
  path   = "core/cert-manager"
  values = {
    enabled = try(local.core.cert_manager.enabled, true)
    config = {
      acme_email                     = try(local.core.cert_manager.config.acme_email, "")
      dns_domain                     = local.rootvars.cluster_url.dns
      preferred_gateway              = local.rootvars.preferred_gateway
      wildcard_reflection_namespaces = try(local.core.reflector.config.wildcard_reflection_namespaces, [])
    }
    secrets = {
      api_token = try(local.secrets.infra.cloudflare.api_token, "")
    }
    chart_version = try(local.core.cert_manager.version, "")
    rootvars      = local.rootvars
  }
}

unit "cnpg" {
  source = "./core/cnpg"
  path   = "core/cnpg"
  values = {
    enabled = try(local.core.cnpg.enabled, true)
    config = {
      controlplane_count = try(length([for node in local.infra.kubernetes.nodes : node if node.role == "controlplane"]), 1)
    }
    chart_version = try(local.core.cnpg.version, "")
  }
}

unit "dnsutils" {
  source = "./core/dnsutils"
  path   = "core/dnsutils"
  values = {
    enabled = try(local.core.dnsutils.enabled, false)
  }
}

unit "kube_prometheus_stack" {
  source = "./core/kube-prometheus-stack"
  path   = "core/kube-prometheus-stack"
  values = {
    enabled = try(local.core.kube_prometheus_stack.enabled, true)
    config = merge(
      try(local.core.kube_prometheus_stack.config, {}),
      { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway }
    )
    chart_version = try(local.core.kube_prometheus_stack.version, "")
  }
}

unit "longhorn" {
  source = "./core/longhorn"
  path   = "core/longhorn"
  values = {
    enabled       = try(local.core.longhorn.enabled, true)
    chart_version = try(local.core.longhorn.version, "")
  }
}

unit "psmdb_operator" {
  source = "./core/psmdb-operator"
  path   = "core/psmdb-operator"
  values = {
    enabled       = try(local.core.psmdb_operator.enabled, true)
    chart_version = try(local.core.psmdb_operator.version, "")
  }
}

unit "reflector" {
  source = "./core/reflector"
  path   = "core/reflector"
  values = {
    enabled = try(local.core.reflector.enabled, true)
    config = {
      wildcard_reflection_namespaces = try(local.core.reflector.config.wildcard_reflection_namespaces, [])
    }
    chart_version = try(local.core.reflector.version, "")
  }
}

unit "tailscale_operator" {
  source = "./core/tailscale-operator"
  path   = "core/tailscale-operator"
  values = {
    enabled = try(local.core.tailscale_operator.enabled, true)
    config = {
      subnet_router_advertised_cidrs = concat(
        try([local.infra.kubernetes.ipcfg.service.ipv4], []),
        try(local.infra.talos.dualstack, true) ? try([local.infra.kubernetes.ipcfg.service.ipv6], []) : []
      )
    }
    secrets = {
      auth_key      = try(local.secrets.infra.tailscale.auth_key, "")
      client_id     = try(local.secrets.infra.tailscale.client_id, "")
      client_secret = try(local.secrets.infra.tailscale.client_secret, "")
    }
    chart_version = try(local.core.tailscale_operator.version, "")
  }
}

unit "traefik" {
  source = "./core/traefik"
  path   = "core/traefik"
  values = {
    enabled = local.rootvars.preferred_gateway == "traefik"
    config = {
      gateway_name = try(local.core.traefik.config.gateway_name, "traefik-gateway")
      dns_domain   = local.rootvars.cluster_url.dns
    }
    versions = try(local.core.traefik.versions, { main = "", crds = "" })
  }
}

unit "tests" {
  source = "./core/testing"
  path   = "core/testing"
  values = {
    enabled = try(local.core.tests.enabled, false)
    config = {
      domain            = local.rootvars.cluster_url.dns
      gateway_name      = try(local.core.tests.config.gateway_name, "")
      gateway_namespace = try(local.core.tests.config.gateway_namespace, "")
    }
  }
}

## --------------------------------------------------------------------------------------------- ##
#  App manifests units                                                                            #
## --------------------------------------------------------------------------------------------- ##
unit "anki" {
  source = "./apps/anki"
  path   = "apps/anki"
  values = {
    enabled = try(local.apps.anki.enabled, false)
    config = merge(
      try(local.apps.anki.config, {}),
      { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway }
    )
    secrets = {
      app = {
        accounts = try(local.secrets.manifests.apps.anki.app.accounts, [])
      }
    }
    image_version = try(local.apps.anki.version, "")
  }
}

unit "miniflux" {
  source = "./apps/miniflux"
  path   = "apps/miniflux"
  values = {
    enabled = try(local.apps.miniflux.enabled, false)
    config = merge(
      try(local.apps.miniflux.config, {}),
      { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway }
    )
    secrets = {
      app = {
        admin_username = try(local.secrets.manifests.apps.miniflux.app.admin_username, "")
        admin_password = try(local.secrets.manifests.apps.miniflux.app.admin_password, "")
      }
      pg = {
        password = try(local.secrets.manifests.apps.miniflux.pg.password, "")
      }
    }
    image_version = try(local.apps.miniflux.version, "")
  }
}

unit "nightscout" {
  source = "./apps/nightscout"
  path   = "apps/nightscout"
  values = {
    enabled = try(local.apps.nightscout.enabled, false)
    config = merge(
      try(local.apps.nightscout.config, {}),
      { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway }
    )
    secrets = {
      app = {
        api_secret = try(local.secrets.manifests.apps.nightscout.app.api_secret, "")
      }
    }
    image_version = try(local.apps.nightscout.version, "")
  }
}

unit "radicale" {
  source = "./apps/radicale"
  path   = "apps/radicale"
  values = {
    enabled = try(local.apps.radicale.enabled, false)
    config = merge(
      try(local.apps.radicale.config, {}),
      { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway }
    )
    secrets = {
      username = try(local.secrets.manifests.apps.radicale.username, "")
      password = try(local.secrets.manifests.apps.radicale.password, "")
    }
    image_version = try(local.apps.radicale.version, "")
  }
}

unit "redmine" {
  source = "./apps/redmine"
  path   = "apps/redmine"
  values = {
    enabled = try(local.apps.redmine.enabled, false)
    config = merge(
      try(local.apps.redmine.config, {}),
      { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway }
    )
    secrets = {
      basic_auth = try(local.secrets.manifests.apps.redmine.basic_auth, try(local.secrets.manifests.apps.misc.basic_auth, { username = "", password_hash = "" }))
      pg = {
        password = try(local.secrets.manifests.apps.redmine.pg.password, "")
      }
    }
    image_version = try(local.apps.redmine.version, "")
  }
}

unit "umami" {
  source = "./apps/umami"
  path   = "apps/umami"
  values = {
    enabled = try(local.apps.umami.enabled, false)
    config = merge(
      try(local.apps.umami.config, {}),
      { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway }
    )
    secrets = {
      app = {
        app_secret = try(local.secrets.manifests.apps.umami.app.app_secret, "")
      }
      basic_auth = try(local.secrets.manifests.apps.umami.basic_auth, try(local.secrets.manifests.apps.misc.basic_auth, { username = "", password_hash = "" }))
      pg = {
        password = try(local.secrets.manifests.apps.umami.pg.password, "")
      }
    }
    image_version = try(local.apps.umami.version, "")
  }
}