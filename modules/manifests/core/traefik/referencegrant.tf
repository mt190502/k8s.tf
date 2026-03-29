## ============================================================================================= ##
#  modules/manifests/core/traefik/referencegrant.tf                                               #
#                                                                                                 #
#  ReferenceGrant allows Gateway in traefik-system to reference TLS secret in cert-manager.       #
#  Required by Gateway API for cross-namespace certificate references.                            #
## ============================================================================================= ##
resource "kubernetes_manifest" "referencegrant" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "allow-traefik-gateway-tls"
      namespace = var.config.tls.secret_namespace
    }
    spec = {
      from = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "Gateway"
          namespace = kubernetes_namespace_v1.this[0].metadata[0].name
        }
      ]
      to = [
        {
          group = ""
          kind  = "Secret"
          name  = var.config.tls.secret_name
        }
      ]
    }
  }
}