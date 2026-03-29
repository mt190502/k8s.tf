## ============================================================================================= ##
#  modules/manifests/apps/radicale/httproute.tf                                                   #
#                                                                                                 #
#  HTTPRoute for Gateway API ingress - routes traffic from Gateway to Service.                    #
#  Requires cert-manager Gateway to be configured.                                                #
#  Hostname: {hostname}.{domain}                                                                  #
#  Includes redirect middleware for /.web paths to mtaha.dev                                      #
#  BackendTLSPolicy for HTTPS backend connection with passHostHeader                              #
## ============================================================================================= ##
resource "kubernetes_manifest" "redirect_middleware" {
  count = (var.enabled && var.config.preferred_gateway == "traefik") ? 1 : 0
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${var.config.name}-redirect"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      redirectRegex = {
        regex       = "^https://${var.config.hostname}.${var.config.domain}/\\.web(.*)?$"
        replacement = "https://${var.config.domain}"
        permanent   = true
      }
    }
  }
}

resource "kubernetes_manifest" "backend_tls_policy" {
  count = (var.enabled && var.config.hostname != null && var.config.preferred_gateway == "traefik") ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "BackendTLSPolicy"
    metadata = {
      name      = "${var.config.name}-tls-policy"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      targetRefs = [
        {
          group = ""
          kind  = "Service"
          name  = kubernetes_service_v1.this[0].metadata[0].name
        }
      ]
      validation = {
        hostname                = "${var.config.hostname}.${var.config.domain}"
        wellKnownCACertificates = "System"
      }
    }
  }
}

resource "kubernetes_manifest" "httproute" {
  count = (var.enabled && var.config.hostname != null) ? 1 : 0
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
                value = "/.web"
              }
            }
          ]
          filters = (var.config.preferred_gateway == "traefik") ? [
            {
              type = "ExtensionRef"
              extensionRef = {
                group = "traefik.io"
                kind  = "Middleware"
                name  = "${var.config.name}-redirect"
              }
            }
          ] : []
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
          filters = [
            {
              type = "RequestHeaderModifier"
              requestHeaderModifier = {
                set = [
                  {
                    name  = "Host"
                    value = "${var.config.hostname}.${var.config.domain}"
                  }
                ]
              }
            }
          ]
          backendRefs = [
            {
              name = kubernetes_service_v1.this[0].metadata[0].name
              port = var.config.port
            }
          ]
        }
      ]
    }
  }
  depends_on = [
    kubernetes_manifest.redirect_middleware,
    kubernetes_manifest.backend_tls_policy
  ]
}