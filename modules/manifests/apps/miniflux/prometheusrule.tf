## ============================================================================================= ##
#  modules/manifests/apps/miniflux/prometheusrule.tf                                              #
## ============================================================================================= ##
resource "kubernetes_manifest" "prometheus_rule" {
  count = (var.enabled && var.config.port != null) ? 1 : 0
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "miniflux-alerts"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
      labels = {
        release                     = "kube-prometheus-stack"
        "app.kubernetes.io/part-of" = var.config.name
      }
    }
    spec = {
      groups = [
        {
          name = "miniflux.rules"
          rules = [
            {
              alert = "MinifluxBrokenFeeds"
              expr  = "miniflux_broken_feeds > 0"
              "for" = "1h"
              labels = {
                severity  = "warning"
                component = "miniflux"
              }
              annotations = {
                summary     = "Miniflux has broken feeds"
                description = "Miniflux has {{ $value | humanize }} feeds that have remained broken for at least one hour."
              }
            },
            {
              alert = "MinifluxFeedRefreshErrorRate"
              expr  = "( sum by (namespace, job) (increase(miniflux_background_feed_refresh_duration_count{status=\"error\"}[30m])) / sum by (namespace, job) (increase(miniflux_background_feed_refresh_duration_count[30m])) ) > 0.25 and sum by (namespace, job) (increase(miniflux_background_feed_refresh_duration_count[30m])) >= 10"
              "for" = "15m"
              labels = {
                severity  = "warning"
                component = "miniflux"
              }
              annotations = {
                summary     = "Miniflux feed refresh error rate is high"
                description = "More than 25% of Miniflux background feed refreshes have failed."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [kubernetes_manifest.servicemonitor]
}
