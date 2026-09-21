## ============================================================================================= ##
#  modules/manifests/core/alloy/prometheusrule.tf                                                 #
## ============================================================================================= ##
resource "kubernetes_manifest" "prometheus_rule" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "alloy-alerts"
      namespace = var.config.kps_namespace
      labels = {
        "app.kubernetes.io/part-of" = helm_release.this.name
      }
    }
    spec = {
      groups = [
        {
          name = "alloy.rules"
          rules = [
            {
              alert = "AlloyConfigLoadFailure"
              expr  = "alloy_config_last_load_successful == 0"
              "for" = "5m"
              labels = {
                severity  = "critical"
                component = "alloy"
              }
              annotations = {
                summary     = "Grafana Alloy failed to load its configuration"
                description = "Alloy pod {{ $labels.pod }} has an invalid or unloadable configuration."
              }
            },
            {
              alert = "AlloyDroppedLogEntries"
              expr  = "sum by (pod, reason) (increase(loki_write_dropped_entries_total[10m])) > 0"
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "alloy"
              }
              annotations = {
                summary     = "Grafana Alloy is dropping log entries"
                description = "Alloy pod {{ $labels.pod }} dropped {{ $value | humanize }} entries in ten minutes because of {{ $labels.reason }}."
              }
            },
            {
              alert = "AlloyLokiWriteRetriesHigh"
              expr  = "sum by (pod) (increase(loki_write_batch_retries_total[10m])) > 20"
              "for" = "10m"
              labels = {
                severity  = "warning"
                component = "alloy"
              }
              annotations = {
                summary     = "Grafana Alloy repeatedly retries Loki writes"
                description = "Alloy pod {{ $labels.pod }} had {{ $value | humanize }} Loki write retries in ten minutes."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.this]
}
