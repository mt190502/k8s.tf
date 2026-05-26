## ============================================================================================= ##
#  modules/manifests/apps/gotify/service.tf                                                       #
#                                                                                                 #
#  ClusterIP Service for the application - exposes pods for internal cluster traffic.             #
#  Used as HTTPRoute backend for Gateway API ingress.                                             #
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
    type             = "ClusterIP"
  }
  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_service_v1" "gotify_bridge" {
  count = var.enabled && try(var.secrets.bridge.gotify_token, "") != "" ? 1 : 0
  metadata {
    name      = "alertmanager-${var.config.name}-bridge"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "alertmanager-${var.config.name}-bridge"
    }
    port {
      port        = 8080
      target_port = 8080
    }
    ip_family_policy = "PreferDualStack"
    type             = "ClusterIP"
  }
  depends_on = [kubernetes_deployment_v1.gotify_bridge]
}