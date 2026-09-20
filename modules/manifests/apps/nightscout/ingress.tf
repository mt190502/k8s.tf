## ============================================================================================= ##
#  modules/manifests/apps/nightscout/ingress.tf                                                   #
#                                                                                                 #
#  Traefik Ingress NGINX provider route with consistent upstream hashing.                         #
#  AAPS does not retain the Traefik sticky cookie, so all Engine.IO requests from one client      #
#  must instead select the same Nightscout pod from a stable request-header hash.                 #
## ============================================================================================= ##
locals {
  hash_ingress_enabled = var.enabled && var.config.hostname != null && try(var.config.ingress_hash_by, null) != null && coalesce(try(var.config.preferred_gateway, null), "traefik") == "traefik"
}

resource "kubernetes_manifest" "ingress" {
  count = local.hash_ingress_enabled ? 1 : 0

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = var.config.name
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
      labels = {
        "app.kubernetes.io/name" = var.config.name
      }
      annotations = {
        "nginx.ingress.kubernetes.io/upstream-hash-by" = var.config.ingress_hash_by
      }
    }
    spec = {
      ingressClassName = "nginx"
      tls = [
        {
          hosts      = ["${var.config.hostname}.${var.config.domain}"]
          secretName = "wildcard-${var.config.domain}-tls"
        }
      ]
      rules = [
        {
          host = "${var.config.hostname}.${var.config.domain}"
          http = {
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = kubernetes_service_v1.this[0].metadata[0].name
                    port = {
                      number = var.config.port
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }

  depends_on = [kubernetes_service_v1.this]
}
