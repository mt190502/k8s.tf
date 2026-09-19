## ============================================================================================= ##
#  modules/manifests/core/traefik/prometheusrule.tf                                               #
## ============================================================================================= ##
resource "kubernetes_manifest" "prometheus_rule" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "traefik-alerts"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
      labels = {
        release                     = "kube-prometheus-stack"
        "app.kubernetes.io/part-of" = "traefik"
      }
    }
    spec = {
      groups = [
        {
          name = "traefik.rules"
          rules = [
            {
              alert = "TraefikHigh5xxRate"
              expr  = "( sum by (exported_service) (rate(traefik_service_requests_total{code=~\"5..\"}[5m])) / sum by (exported_service) (rate(traefik_service_requests_total[5m])) ) > 0.05 and sum by (exported_service) (rate(traefik_service_requests_total[5m])) > 0.1"
              "for" = "10m"
              labels = {
                severity  = "warning"
                component = "traefik"
              }
              annotations = {
                summary     = "Traefik backend has a high HTTP 5xx rate"
                description = "Backend {{ $labels.exported_service }} has returned more than 5% HTTP 5xx responses for 10 minutes."
              }
            },
            {
              alert = "TraefikHighLatency"
              expr  = "histogram_quantile(0.95, sum by (le, exported_service) (rate(traefik_service_request_duration_seconds_bucket[5m]))) > 2 and on(exported_service) sum by (exported_service) (rate(traefik_service_requests_total[5m])) > 0.1"
              "for" = "15m"
              labels = {
                severity  = "warning"
                component = "traefik"
              }
              annotations = {
                summary     = "Traefik backend latency is high"
                description = "Backend {{ $labels.exported_service }} p95 request duration has exceeded two seconds for 15 minutes (current: {{ $value | humanizeDuration }})."
              }
            },
            {
              alert = "TraefikTLSCertificateExpiringSoon"
              expr  = "min by (cn, sans, serial) (traefik_tls_certs_not_after) - time() < 14 * 24 * 60 * 60"
              "for" = "1h"
              labels = {
                severity  = "warning"
                component = "traefik"
              }
              annotations = {
                summary     = "TLS certificate expires in less than 14 days"
                description = "Certificate {{ $labels.cn }} expires in {{ $value | humanizeDuration }}."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.this]
}
