## ============================================================================================= ##
#  modules/manifests/terragrunt.stack.hcl --- Core manifests sub-stack                            #
## ============================================================================================= ##
locals {
  secrets = try(values.secrets, {})
  apps    = try(values.apps, {})
}

unit "longhorn" {
  source = "./core/longhorn"
  path   = "core/longhorn"
  values = {
    enabled = try(local.apps.longhorn.enabled, true)
    versions = {
      chart = try(local.apps.longhorn.version, "")
    }
  }
}

unit "reflector" {
  source = "./core/reflector"
  path   = "core/reflector"
  values = {
    enabled = try(local.apps.reflector.enabled, true)
    versions = {
      chart = try(local.apps.reflector.version, "")
    }
  }
}

unit "cnpg" {
  source = "./core/cnpg"
  path   = "core/cnpg"
  values = {
    enabled = try(local.apps.cnpg.enabled, true)
    versions = {
      chart = try(local.apps.cnpg.version, "")
    }
  }
}

unit "kube_prometheus_stack" {
  source = "./core/kube-prometheus-stack"
  path   = "core/kube-prometheus-stack"
  values = {
    enabled = try(local.apps.kube_prometheus_stack.enabled, true)
    versions = {
      chart = try(local.apps.kube_prometheus_stack.version, "")
    }
  }
}

unit "cert_manager" {
  source = "./core/cert-manager"
  path   = "core/cert-manager"
  values = {
    enabled = try(local.apps.cert_manager.enabled, true)
    config = {
      acme_email                     = try(local.apps.cert_manager.acme_email, "")
      dns_domain                     = try(local.apps.cert_manager.dns_domain, "")
      wildcard_reflection_namespaces = try(local.apps.cert_manager.wildcard_reflection_namespaces, [])
    }
    secrets = {
      api_token = try(local.secrets.cloudflare.api_token, "")
    }
    versions = {
      chart = try(local.apps.cert_manager.version, "")
    }
  }
}

unit "tests" {
  source = "./core/testing"
  path   = "core/testing"
  values = {
    enabled = try(local.apps.tests.enabled, true)
    config  = try(local.apps.tests.config, {})
  }
}