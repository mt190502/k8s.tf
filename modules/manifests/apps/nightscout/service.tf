## ============================================================================================= ##
#  modules/manifests/apps/nightscout/service.tf                                                   #
#                                                                                                 #
#  ClusterIP Service for Nightscout application - exposes port 1337 for HTTPRoute backend.        #
## ============================================================================================= ##
resource "kubernetes_service_v1" "this" {
  metadata {
    name      = "nightscout"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "nightscout"
    }
    port {
      port        = 1337
      target_port = 1337
    }
  }
  depends_on = [
    kubernetes_namespace_v1.this
  ]
}