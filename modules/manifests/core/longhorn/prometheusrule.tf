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
        "app.kubernetes.io/part-of" = helm_release.this.name
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
              alert = "LonghornVolumeNearlyFull"
              expr  = "max by (pvc, pvc_namespace, volume) (100 * longhorn_volume_actual_size_bytes / longhorn_volume_capacity_bytes) >= 90"
              "for" = "30m"
              labels = {
                severity  = "warning"
                component = "longhorn"
              }
              annotations = {
                summary     = "Longhorn volume real size is at or above 90% of its provisioned size"
                description = "Volume {{ $labels.pvc_namespace }}/{{ $labels.pvc }} holds {{ $value | humanize }}% of its provisioned size, counting data plus snapshots. Uncontrolled snapshots or a volume excluded from recurring jobs without a filesystem trim make real size converge to (or exceed) the PVC size on every replica node."
              }
            },
            {
              alert = "LonghornVolumeSpaceUsageHigh"
              expr  = "max by (namespace, persistentvolumeclaim) (100 * (1 - kubelet_volume_stats_available_bytes{job=\"kubelet\", metrics_path=\"/metrics\"} / kubelet_volume_stats_capacity_bytes{job=\"kubelet\", metrics_path=\"/metrics\"}) and on (namespace, persistentvolumeclaim) kube_persistentvolumeclaim_info{storageclass=\"longhorn\"}) > 90"
              "for" = "15m"
              labels = {
                severity  = "warning"
                component = "longhorn"
              }
              annotations = {
                summary     = "Longhorn PVC filesystem usage is above 90%"
                description = "PVC {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} filesystem is {{ $value | humanize }}% full, excluding Longhorn snapshots."
              }
            }
          ]
        }
      ]
    }
  }

  field_manager {
    #~ The rules field was co-owned by a one-off kubectl patch (2026-09-20) with identical
    #~ content; take ownership so rule updates can apply. Precedent: core/gotify/db.tf.
    force_conflicts = true
  }

  depends_on = [helm_release.this]
}
