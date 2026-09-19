## ============================================================================================= ##
#  modules/manifests/core/longhorn/prometheusrule.tf                                              #
## ============================================================================================= ##
resource "kubernetes_manifest" "prometheus_rule" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "longhorn-alerts"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
      labels = {
        release                     = "kube-prometheus-stack"
        "app.kubernetes.io/part-of" = "longhorn"
      }
    }
    spec = {
      groups = [
        {
          name = "longhorn.rules"
          rules = [
            {
              alert = "LonghornVolumeDegraded"
              expr  = "max by (volume, pvc, pvc_namespace, node) (longhorn_volume_robustness{state=\"degraded\"}) == 1"
              "for" = "10m"
              labels = {
                severity  = "warning"
                component = "longhorn"
              }
              annotations = {
                summary     = "Longhorn volume is degraded"
                description = "Volume {{ $labels.volume }} for {{ $labels.pvc_namespace }}/{{ $labels.pvc }} is degraded on {{ $labels.node }}."
              }
            },
            {
              alert = "LonghornVolumeFaulted"
              expr  = "max by (volume, pvc, pvc_namespace, node) (longhorn_volume_robustness{state=\"faulted\"}) == 1"
              "for" = "2m"
              labels = {
                severity  = "critical"
                component = "longhorn"
              }
              annotations = {
                summary     = "Longhorn volume is faulted"
                description = "Volume {{ $labels.volume }} for {{ $labels.pvc_namespace }}/{{ $labels.pvc }} is faulted."
              }
            },
            {
              alert = "LonghornNodeNotReady"
              expr  = "longhorn_node_status{condition=\"ready\"} == 0"
              "for" = "5m"
              labels = {
                severity  = "critical"
                component = "longhorn"
              }
              annotations = {
                summary     = "Longhorn node is not ready"
                description = "Longhorn node {{ $labels.node }} has not been ready for five minutes."
              }
            },
            {
              alert = "LonghornDiskNotReady"
              expr  = "longhorn_disk_status{condition=\"ready\"} == 0"
              "for" = "10m"
              labels = {
                severity  = "warning"
                component = "longhorn"
              }
              annotations = {
                summary     = "Longhorn disk is not ready"
                description = "Disk {{ $labels.disk }} on {{ $labels.node }} is not ready."
              }
            },
            {
              alert = "LonghornDiskSpaceUsageHigh"
              expr  = "100 * longhorn_disk_usage_bytes / longhorn_disk_capacity_bytes >= 90"
              "for" = "15m"
              labels = {
                severity  = "warning"
                component = "longhorn"
              }
              annotations = {
                summary     = "Longhorn disk usage is at or above 90%"
                description = "Disk {{ $labels.disk }} on {{ $labels.node }} is {{ $value | humanize }}% full."
              }
            },
            {
              alert = "LonghornVolumeSpaceUsageHigh"
              expr  = "max by (volume, pvc, pvc_namespace) (100 * longhorn_volume_actual_size_bytes / longhorn_volume_capacity_bytes) > 90"
              "for" = "15m"
              labels = {
                severity  = "warning"
                component = "longhorn"
              }
              annotations = {
                summary     = "Longhorn volume reported usage is above 90%"
                description = "Volume {{ $labels.volume }} for {{ $labels.pvc_namespace }}/{{ $labels.pvc }} reports {{ $value | humanize }}% actual allocated or snapshot-accounted size relative to nominal capacity."
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [helm_release.this]
}
