## ============================================================================================= ##
#  modules/manifests/core/renovate/prometheusrule.tf                                              #
#                                                                                                 #
#  Renovate has no Prometheus metrics endpoint, so the runner is monitored through Kubernetes      #
#  object state (kube-state-metrics) instead.                                                      #
#  RenovateRunFailed only counts Jobs owned by the runner CronJob (not the cache cleanup) and     #
#  only fires while no run has succeeded since the failure: failed Jobs stay in the history       #
#  for up to 24h, so a single transient GitHub error must not keep the alert firing after the     #
#  next run recovered. Without any recorded success, every failed run counts.                     #
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
              expr = join(" ", [
                "(kube_job_status_start_time{namespace=\"${local.namespace}\"}",
                "* on (namespace, job_name) group_left ()",
                "(kube_job_failed{namespace=\"${local.namespace}\", condition=\"true\"} > 0)",
                "* on (namespace, job_name) group_left ()",
                "kube_job_owner{namespace=\"${local.namespace}\", owner_kind=\"CronJob\", owner_name=\"${local.cronjob}\"})",
                "> on (namespace) group_left ()",
                "(max by (namespace) (kube_cronjob_status_last_successful_time{namespace=\"${local.namespace}\", cronjob=\"${local.cronjob}\"})",
                "or on (namespace) max by (namespace) (kube_job_status_start_time{namespace=\"${local.namespace}\"}) * 0)",
              ])
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "renovate"
              }
              annotations = {
                summary     = "Self-hosted Renovate run failed"
                description = "A Renovate CronJob run in namespace ${local.namespace} failed and no run has succeeded since. Check the job logs for datasource or authentication errors."
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
