## ============================================================================================= ##
#  modules/manifests/core/cnpg/prometheusrule.tf                                                  #
## ============================================================================================= ##
resource "kubernetes_manifest" "prometheus_rule" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "cloudnative-pg-alerts"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
      labels = {
        release                     = "kube-prometheus-stack"
        "app.kubernetes.io/part-of" = "cnpg"
      }
    }
    spec = {
      groups = [
        {
          name = "cloudnative-pg.rules"
          rules = [
            {
              alert = "CNPGCollectorDown"
              expr  = "cnpg_collector_up == 0"
              "for" = "5m"
              labels = {
                severity  = "critical"
                component = "cloudnative-pg"
              }
              annotations = {
                summary     = "CloudNativePG collector cannot query PostgreSQL"
                description = "CNPG collector is down for {{ $labels.namespace }}/{{ $labels.pod }}."
              }
            },
            {
              alert = "CNPGReplicationLagHigh"
              expr  = "cnpg_pg_replication_lag > 300"
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "cloudnative-pg"
              }
              annotations = {
                summary     = "CloudNativePG replica lag is above five minutes"
                description = "Replica {{ $labels.namespace }}/{{ $labels.pod }} is {{ $value | humanizeDuration }} behind."
              }
            },
            {
              alert = "CNPGReplicaFailingReplication"
              expr  = "cnpg_pg_replication_in_recovery > cnpg_pg_replication_is_wal_receiver_up"
              "for" = "5m"
              labels = {
                severity  = "critical"
                component = "cloudnative-pg"
              }
              annotations = {
                summary     = "CloudNativePG replica is not receiving WAL"
                description = "Replica {{ $labels.namespace }}/{{ $labels.pod }} is in recovery but its WAL receiver is down."
              }
            },
            {
              alert = "CNPGWALArchivingFailed"
              expr  = "cnpg_pg_stat_archiver_last_failed_time - cnpg_pg_stat_archiver_last_archived_time > 1"
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "cloudnative-pg"
              }
              annotations = {
                summary     = "CloudNativePG WAL archiving is failing"
                description = "The latest archive operation for {{ $labels.namespace }}/{{ $labels.pod }} failed."
              }
            },
            {
              alert = "CNPGLongRunningTransaction"
              expr  = "cnpg_backends_max_tx_duration_seconds > 300"
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "cloudnative-pg"
              }
              annotations = {
                summary     = "CloudNativePG has a long-running transaction"
                description = "A transaction on {{ $labels.namespace }}/{{ $labels.pod }} has run for {{ $value | humanizeDuration }}."
              }
            },
            {
              alert = "CNPGDatabaseXIDAgeHigh"
              expr  = "cnpg_pg_database_xid_age > 300000000"
              "for" = "15m"
              labels = {
                severity  = "warning"
                component = "cloudnative-pg"
              }
              annotations = {
                summary     = "PostgreSQL database transaction ID age is high"
                description = "Database {{ $labels.datname }} on {{ $labels.namespace }}/{{ $labels.pod }} has XID age {{ $value | humanize }}."
              }
            },
            {
              alert = "CNPGManualSwitchoverRequired"
              expr  = "cnpg_collector_manual_switchover_required == 1"
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "cloudnative-pg"
              }
              annotations = {
                summary     = "CloudNativePG requires a manual switchover"
                description = "Cluster instance {{ $labels.namespace }}/{{ $labels.pod }} requires manual switchover."
              }
            },
            {
              alert = "CNPGOperatorReconcileErrors"
              expr  = "sum by (controller) (increase(controller_runtime_reconcile_errors_total{job=\"cnpg-system/cloudnative-pg\"}[10m])) > 5"
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "cloudnative-pg"
              }
              annotations = {
                summary     = "CloudNativePG operator has repeated reconcile errors"
                description = "Controller {{ $labels.controller }} had {{ $value | humanize }} reconcile errors in ten minutes."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.this]
}
