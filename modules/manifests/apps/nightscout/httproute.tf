## ============================================================================================= ##
#  modules/manifests/apps/nightscout/httproute.tf                                                 #
#                                                                                                 #
#  HTTPRoute for Gateway API ingress - routes traffic from Gateway to Service.                    #
#  Requires cert-manager Gateway to be configured.                                                #
#  Hostname: {hostname}.{domain}                                                                  #
## ============================================================================================= ##
resource "kubernetes_manifest" "httproute" {
  count = var.config.hostname != null ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = var.config.name
      namespace = kubernetes_namespace_v1.this.metadata[0].name
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
        }
      ]
    }
  }
}