## ============================================================================================= ##
#  modules/manifests/core/kyverno/prometheusrule.tf                                               #
## ============================================================================================= ##
resource "kubernetes_manifest" "prometheus_rule" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "kyverno-alerts"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
      labels = {
        "app.kubernetes.io/part-of" = helm_release.this.name
      }
    }
    spec = {
      groups = [
        {
          name = "kyverno.rules"
          rules = [
            {
              alert = "KyvernoAdmissionHighLatency"
              expr  = "histogram_quantile( 0.99, sum(rate(kyverno_admission_review_duration_seconds_bucket[5m])) by (le) ) > 1"
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "kyverno"
              }
              annotations = {
                summary     = "Kyverno admission review p99 latency is elevated"
                description = "Kyverno admission p99 latency is {{ $value | humanizeDuration }}, above the one-second threshold."
                runbook_url = "https://kyverno.io/docs/guides/monitoring/#admission-latency-high"
              }
            },
            {
              alert = "KyvernoPolicyExecutionErrors"
              expr  = "sum by (policy_name, rule_name, rule_type) ( increase(kyverno_policy_results_total{rule_result=\"error\"}[10m]) ) > 0"
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "kyverno"
              }
              annotations = {
                summary     = "Kyverno policy execution errors detected"
                description = "Policy {{ $labels.policy_name }} rule {{ $labels.rule_name }} returned execution errors."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.this]
}
