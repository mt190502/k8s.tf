## ============================================================================================= ##
#  modules/manifests/apps/syncstorage-rs/httproute.tf                                             #
#                                                                                                 #
#  HTTPRoute for Gateway API ingress - routes traffic from Gateway to Service.                    #
#  Requires cert-manager Gateway to be configured.                                                #
#  Hostname: {hostname}.{domain}                                                                  #
#                                                                                                 #
#  h2c incompatibility is handled via nginx sidecar in the Deployment, not here.                  #
## ============================================================================================= ##
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
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = kubernetes_service_v1.this[0].metadata[0].name
              port = var.config.port
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
        }
      ]
    }
  }
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