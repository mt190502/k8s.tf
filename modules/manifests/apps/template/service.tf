## ============================================================================================= ##
#  modules/manifests/apps/<<<template>>>/service.tf                                               #
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

## --------------------------------------------------------------------------------------------- ##
#  Headless Service for StatefulSet - provides stable network identity for each pod.              #
#  Pod DNS: {pod-name}.{service-name}.{namespace}.svc.cluster.local                               #
## --------------------------------------------------------------------------------------------- ##
resource "kubernetes_service_v1" "headless" {
  count = (var.enabled && var.config.port != null) ? 1 : 0
  metadata {
    name      = "${var.config.name}-headless"
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
    cluster_ip = "None"
  }
  depends_on = [kubernetes_namespace_v1.this]
}