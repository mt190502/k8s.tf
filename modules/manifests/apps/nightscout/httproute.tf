## ============================================================================================= ##
#  modules/manifests/apps/nightscout/httproute.tf                                                 #
#                                                                                                 #
#  HTTPRoute for Nightscout - routes traffic from Gateway to the nightscout Service.              #
#  Hostname: t1d.{domain}                                                                         #
## ============================================================================================= ##
resource "kubernetes_manifest" "nightscout_httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "nightscout-httproute"
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
        "t1d.${var.config.domain}"
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
              name = kubernetes_service_v1.this.metadata[0].name
              port = 1337
            }
          ]
        }
      ]
    }
  }
  depends_on = [kubernetes_service_v1.this]
}