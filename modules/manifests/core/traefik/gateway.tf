## ============================================================================================= ##
#  modules/manifests/core/traefik/gateway.tf                                                      #
#                                                                                                 #
#  Creates the shared Gateway (HTTPS :443, *.dns_domain) for Traefik.                             #
#  TLS is terminated with the wildcard certificate from cert-manager.                             #
#  Uses null_resource + kubectl because the kubernetes provider does not support CRDs well.       #
## ============================================================================================= ##
resource "kubernetes_manifest" "gateway" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = var.config.gateway_name
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      gatewayClassName = "traefik"
      listeners = [
        {
          name     = "websecure"
          hostname = "*.${var.config.dns_domain}"
          port     = 443
          protocol = "HTTPS"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                name      = var.config.tls.secret_name
                namespace = var.config.tls.secret_namespace
              }
            ]
          }
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        }
      ]
    }
  }
  depends_on = [
    helm_release.this,
  ]
}
