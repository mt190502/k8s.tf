## ============================================================================================= ##
#  modules/manifests/core/traefik/gatewayclass.tf                                                 #
#                                                                                                 #
#  GatewayClass for Traefik Gateway API.                                                          #
## ============================================================================================= ##
resource "kubernetes_manifest" "gatewayclass" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "traefik"
    }
    spec = {
      controllerName = "traefik.io/gateway-controller"
    }
  }
  depends_on = [
    helm_release.this,
  ]
}