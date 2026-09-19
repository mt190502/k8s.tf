## ============================================================================================= ##
#  Prometheus ServiceMonitor for Miniflux's native metrics endpoint.                              #
## ============================================================================================= ##
resource "kubernetes_manifest" "servicemonitor" {
  count = (var.enabled && var.config.port != null) ? 1 : 0
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = var.config.name
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
      labels = {
        "app.kubernetes.io/name" = var.config.name
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = var.config.name
        }
      }
      endpoints = [
        {
          port   = "http"
          path   = "/metrics"
          scheme = "http"
        }
      ]
    }
  }
  depends_on = [kubernetes_service_v1.this]
}
