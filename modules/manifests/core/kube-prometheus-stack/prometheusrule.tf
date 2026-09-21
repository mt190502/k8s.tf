## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/prometheusrule.tf                                 #
#                                                                                                 #
#  Replacement for the chart's default NodeDiskIOSaturation alert (disabled through               #
#  defaultRules.disabled). Longhorn presents each PVC as an iSCSI block device whose              #
#  aqu-sz counts in-flight network requests, so it reports saturation on healthy disks.           #
#  The exclusion keeps physical device monitoring while ignoring iSCSI volumes.                   #
## ============================================================================================= ##
resource "kubernetes_manifest" "node_disk_io_saturation" {
  count = var.enabled ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "node-disk-io-saturation"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
      labels = {
        "app.kubernetes.io/part-of" = helm_release.this.name
      }
    }
    spec = {
      groups = [
        {
          name = "node-exporter.rules"
          rules = [
            {
              alert = "NodeDiskIOSaturation"
              expr  = "rate(node_disk_io_time_weighted_seconds_total{job=\"node-exporter\", device=~\"(/dev/)?(mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|md.+|dasd.+)\"}[5m]) > 10 and on(instance, device) (node_disk_info{job=\"node-exporter\", path!~\".*iscsi.*\"})"
              "for" = "30m"
              labels = {
                severity  = "warning"
                component = "node-exporter"
              }
              annotations = {
                summary     = "Disk IO queue is high."
                description = "Disk IO queue (aqu-sq) is high on {{ $labels.device }} at {{ $labels.instance }}, has been above 10 for the last 30 minutes, is currently at {{ printf \"%.2f\" $value }}. Physical devices only; Longhorn iSCSI volumes are excluded."
              }
            }
          ]
        }
      ]
    }
  }
}
