## ============================================================================================= ##
#  modules/manifests/terragrunt.stack.hcl --- Core manifests sub-stack                            #
## ============================================================================================= ##
locals {
  apps     = try(values.apps, {})
  core     = try(values.core, {})
  rootvars = try(values.rootvars, { cluster_url = { dns = "mock.local" }, preferred_gateway = "cilium" })
}

## --------------------------------------------------------------------------------------------- ##
#  Core manifests units                                                                           #
## --------------------------------------------------------------------------------------------- ##
unit "cert_manager" {
  source = "./core/cert-manager"
  path   = "core/cert-manager"
  values = {
    enabled = try(local.core.cert_manager.enabled, true)
    config = {
      acme_email                     = try(local.core.cert_manager.config.acme_email, "")
      dns_domain                     = try(local.core.cert_manager.config.dns_domain, "")
      wildcard_reflection_namespaces = try(local.core.reflector.config.wildcard_reflection_namespaces, [])
    }
    secrets       = try(local.core.cert_manager.secrets, { api_token = "" })
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
      controlplane_count = try(local.core.cnpg.config.controlplane_count, 1)
    }
    chart_version = try(local.core.cnpg.version, "")
  }
}

unit "kube_prometheus_stack" {
  source = "./core/kube-prometheus-stack"
  path   = "core/kube-prometheus-stack"
  values = {
    enabled       = try(local.core.kube_prometheus_stack.enabled, true)
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
      subnet_router_advertised_cidrs = try(local.core.tailscale_operator.config.subnet_router_advertised_cidrs, [])
    }
    secrets       = try(local.core.tailscale_operator.secrets, { auth_key = "", client_id = "", client_secret = "" })
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
      domain       = try(local.core.tests.config.domain, "mock.local")
      gateway_name = try(local.core.tests.config.gateway_name, "")
      namespace    = try(local.core.tests.config.namespace, "")
    }
  }
}

## --------------------------------------------------------------------------------------------- ##
#  App manifests units                                                                            #
## --------------------------------------------------------------------------------------------- ##
unit "nightscout" {
  source = "./apps/nightscout"
  path   = "apps/nightscout"
  values = {
    enabled       = try(local.apps.nightscout.enabled, false)
    config        = merge(try(local.apps.nightscout.config, {}), { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway })
    secrets       = try(local.apps.nightscout.secrets, { api_secret = "" })
    image_version = try(local.apps.nightscout.version, "")
  }
}

unit "radicale" {
  source = "./apps/radicale"
  path   = "apps/radicale"
  values = {
    enabled       = try(local.apps.radicale.enabled, false)
    config        = merge(try(local.apps.radicale.config, {}), { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway })
    secrets       = try(local.apps.radicale.secrets, {})
    image_version = try(local.apps.radicale.version, "")
  }
}

unit "redmine" {
  source = "./apps/redmine"
  path   = "apps/redmine"
  values = {
    enabled       = try(local.apps.redmine.enabled, false)
    config        = merge(try(local.apps.redmine.config, {}), { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway })
    secrets       = try(local.apps.redmine.secrets, {})
    image_version = try(local.apps.redmine.version, "")
  }
}

unit "umami" {
  source = "./apps/umami"
  path   = "apps/umami"
  values = {
    enabled       = try(local.apps.umami.enabled, false)
    config        = merge(try(local.apps.umami.config, {}), { domain = local.rootvars.cluster_url.dns, preferred_gateway = local.rootvars.preferred_gateway })
    secrets       = try(local.apps.umami.secrets, {})
    image_version = try(local.apps.umami.version, "")
  }
}