## ============================================================================================= ##
#  modules/manifests/terragrunt.stack.hcl --- Core manifests sub-stack                            #
## ============================================================================================= ##
locals {
  a = try(values.apps, {})
  c = try(values.config, {})
  s = try(values.secrets, {})
}

unit "longhorn" {
  source = "./core/longhorn"
  path   = "core/longhorn"
  values = {
    enabled = try(local.a.longhorn.enabled, true)
    versions = {
      chart = try(local.a.longhorn.version, "")
    }
  }
}

unit "reflector" {
  source = "./core/reflector"
  path   = "core/reflector"
  values = {
    enabled = try(local.a.reflector.enabled, true)
    config = {
      wildcard_reflection_namespaces = try(local.a.reflector.wildcard_reflection_namespaces, [])
    }
    versions = {
      chart = try(local.a.reflector.version, "")
    }
  }
}

unit "cnpg" {
  source = "./core/cnpg"
  path   = "core/cnpg"
  values = {
    enabled = try(local.a.cnpg.enabled, true)
    versions = {
      chart = try(local.a.cnpg.version, "")
    }
  }
}

unit "kube_prometheus_stack" {
  source = "./core/kube-prometheus-stack"
  path   = "core/kube-prometheus-stack"
  values = {
    enabled = try(local.a.kube_prometheus_stack.enabled, true)
    versions = {
      chart = try(local.a.kube_prometheus_stack.version, "")
    }
  }
}

unit "cert_manager" {
  source = "./core/cert-manager"
  path   = "core/cert-manager"
  values = {
    enabled = try(local.a.cert_manager.enabled, true)
    config = {
      acme_email                     = try(local.a.cert_manager.acme_email, "")
      dns_domain                     = try(local.c.dns_domain, "")
      wildcard_reflection_namespaces = try(local.a.reflector.wildcard_reflection_namespaces, [])
    }
    secrets = {
      api_token = try(local.s.cloudflare.api_token, "")
    }
    versions = {
      chart = try(local.a.cert_manager.version, "")
    }
  }
}

unit "tests" {
  source = "./core/testing"
  path   = "core/testing"
  values = {
    enabled = try(local.a.tests.enabled, true)
    config = {
      domain = try(local.c.dns_domain, "mock.local")
    }
  }
}