## ============================================================================================= ##
#  modules/manifests/apps/silverbullet/service.tf                                                 #
#                                                                                                 #
#  ClusterIP Service for the application - used as HTTPRoute backend.                             #
## ============================================================================================= ##
resource "kubernetes_service_v1" "this" {
  count = (var.enabled && var.config.port != null) ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = var.config.name
    }
    port {
      port        = var.config.port
      target_port = var.config.port
    }
    ip_family_policy = "PreferDualStack"
    ip_families      = ["IPv4", "IPv6"]
    type             = "ClusterIP"
  }
  depends_on = [kubernetes_namespace_v1.this]
}
