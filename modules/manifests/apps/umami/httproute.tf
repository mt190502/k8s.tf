## ============================================================================================= ##
#  modules/manifests/apps/umami/httproute.tf                                                      #
#                                                                                                 #
#  HTTPRoute for Gateway API ingress - routes traffic from Gateway to Service.                    #
#  Requires cert-manager Gateway to be configured.                                                #
#  Hostname: {hostname}.{domain}                                                                  #
#                                                                                                 #
#  Two routes:                                                                                    #
#    1. /api with POST/OPTIONS methods + Referer header regex validation                          #
#    2. / fallback for all other requests                                                         #
## ============================================================================================= ##
resource "kubernetes_manifest" "httproute" {
  count = (var.enabled && var.config.hostname != null && !local.hash_ingress_enabled) ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = var.config.name
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name      = var.config.gateway_name
          namespace = var.config.gateway_namespace
        }
      ]
      hostnames = [
        "${var.config.hostname}.${var.config.domain}"
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/api"
              }
              method = "POST"
              headers = [
                {
                  type  = "RegularExpression"
                  name  = "Referer"
                  value = "^https?://(?:[a-zA-Z0-9-]+\\.)*${var.config.domain}"
                }
              ]
            },
            {
              path = {
                type  = "PathPrefix"
                value = "/api"
              }
              method = "OPTIONS"
              headers = [
                {
                  type  = "RegularExpression"
                  name  = "Referer"
                  value = "^https?://(?:[a-zA-Z0-9-]+\\.)*${var.config.domain}"
                }
              ]
            }
          ]
          backendRefs = [
            {
              name  = local.traefik_service_enabled ? local.traefik_service_name : kubernetes_service_v1.this[0].metadata[0].name
              group = local.traefik_service_enabled ? "traefik.io" : ""
              kind  = local.traefik_service_enabled ? "TraefikService" : "Service"
              port  = var.config.port
            }
          ]
        },
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          filters = flatten([
            var.config.basic_auth && var.config.preferred_gateway == "traefik" ? [{
              type = "ExtensionRef"
              extensionRef = {
                group = "traefik.io"
                kind  = "Middleware"
                name  = "${var.config.name}-basic-auth"
              }
            }] : []
          ])
          backendRefs = [
            {
              name  = local.traefik_service_enabled ? local.traefik_service_name : kubernetes_service_v1.this[0].metadata[0].name
              group = local.traefik_service_enabled ? "traefik.io" : ""
              kind  = local.traefik_service_enabled ? "TraefikService" : "Service"
              port  = var.config.port
            }
          ]
        }
      ]
    }
  }
  depends_on = [null_resource.traefik_service]
}

resource "kubernetes_secret_v1" "basic_auth" {
  count = (var.enabled && var.config.basic_auth && var.config.preferred_gateway == "traefik") ? 1 : 0
  metadata {
    name      = "${var.config.name}-basic-auth"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  type = "Opaque"
  data = {
    users = "${var.secrets.basic_auth.username}:${var.secrets.basic_auth.password_hash}"
  }
}

resource "kubernetes_manifest" "basic_auth_middleware" {
  count = (var.enabled && var.config.basic_auth && var.config.preferred_gateway == "traefik") ? 1 : 0
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${var.config.name}-basic-auth"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      basicAuth = {
        secret = kubernetes_secret_v1.basic_auth[0].metadata[0].name
      }
    }
  }
  depends_on = [kubernetes_secret_v1.basic_auth]
}