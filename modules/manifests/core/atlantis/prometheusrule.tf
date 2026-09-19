## ============================================================================================= ##
#  modules/manifests/core/atlantis/prometheusrule.tf                                              #
## ============================================================================================= ##
resource "kubernetes_manifest" "prometheus_rule" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "atlantis-alerts"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
      labels = {
        release                     = "kube-prometheus-stack"
        "app.kubernetes.io/part-of" = "atlantis"
      }
    }
    spec = {
      groups = [
        {
          name = "atlantis.rules"
          rules = [
            {
              alert = "AtlantisOperationErrors"
              expr  = "sum by (namespace, pod) ( increase(atlantis_builder_execution_error[15m]) + increase(atlantis_project_execution_error[15m]) + increase(atlantis_pullclosed_cleanup_execution_error[15m]) ) > 0"
              "for" = "1m"
              labels = {
                severity  = "warning"
                component = "atlantis"
              }
              annotations = {
                summary     = "Atlantis encountered an internal operation error"
                description = "Atlantis pod {{ $labels.namespace }}/{{ $labels.pod }} encountered {{ $value | humanize }} internal errors."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.atlantis]
}
