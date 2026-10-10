## ============================================================================================= ##
#  modules/manifests/apps/picoshare/httproute.tf                                                  #
#                                                                                                 #
#  HTTPRoute for Gateway API ingress - routes traffic from Gateway to Service.                    #
#  Requires cert-manager Gateway to be configured.                                                #
#  Hostname: {hostname}.{domain}                                                                  #
#                                                                                                 #
#  Basic auth is intentionally not supported: shared download links must stay reachable            #
#  without a second login. Access control is PicoShare's own admin login.                         #
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
              name  = kubernetes_service_v1.this[0].metadata[0].name
              group = ""
              kind  = "Service"
              port  = var.config.port
            }
          ]
        }
      ]
    }
  }
  depends_on = [kubernetes_service_v1.this]
}
