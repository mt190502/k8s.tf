## ============================================================================================= ##
#  modules/manifests/core/renovate/prometheusrule.tf                                              #
#                                                                                                 #
#  Renovate has no Prometheus metrics endpoint, so the runner is monitored through Kubernetes      #
#  object state (kube-state-metrics) instead.                                                      #
## ============================================================================================= ##
locals {
  namespace = "renovate-system"
  cronjob   = "renovate"
}

resource "kubernetes_manifest" "prometheus_rule" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "renovate-alerts"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
      labels = {
        "app.kubernetes.io/part-of" = var.config.name
      }
    }
    spec = {
      groups = [
        {
          name = "renovate.rules"
          rules = [
            {
              alert = "RenovateRunFailed"
              expr  = "kube_job_failed{namespace=\"${local.namespace}\", job_name=~\"${local.cronjob}-.*\"} > 0"
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "renovate"
              }
              annotations = {
                summary     = "Self-hosted Renovate run failed"
                description = "A Renovate CronJob run in namespace ${local.namespace} failed. Check the job logs for datasource or authentication errors."
              }
            },
            {
              alert = "RenovateRunStale"
              expr  = "time() - max(kube_cronjob_status_last_successful_time{namespace=\"${local.namespace}\", cronjob=\"${local.cronjob}\"}) > 129600"
              "for" = "15m"
              labels = {
                severity  = "warning"
                component = "renovate"
              }
              annotations = {
                summary     = "Self-hosted Renovate has not completed successfully in 36h"
                description = "No successful Renovate run in namespace ${local.namespace} for more than 36 hours. Dependency updates are silently not being created."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [kubernetes_namespace_v1.this]
}
