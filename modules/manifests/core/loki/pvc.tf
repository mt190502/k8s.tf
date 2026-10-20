## ============================================================================================= ##
#  modules/manifests/core/loki/pvc.tf                                                             #
#                                                                                                 #
#  Opts the Loki single-binary PVC out of the Longhorn "default" recurring-job group, so          #
#  the nightly-snapshot and monthly-backup jobs skip it (same labels as the Prometheus TSDB       #
#  PVC in kube-prometheus-stack). Loki keeps chunks and index in S3; the PVC holds only WAL       #
#  and cache data, and snapshots of it only pin overwritten blocks on every replica node.         #
#                                                                                                 #
#  The labels are set on the existing PVC, not via singleBinary.persistence.labels: changes       #
#  to StatefulSet volumeClaimTemplates are forbidden, and the chart's recreate job handles        #
#  only size changes. With recurring-job.longhorn.io/source = enabled, Longhorn syncs the         #
#  PVC's recurring-job labels to the volume and removes its "default" group label.                #
## ============================================================================================= ##
resource "kubernetes_labels" "loki_storage_pvc" {
  api_version = "v1"
  kind        = "PersistentVolumeClaim"
  metadata {
    #~ <claim name>-<statefulset name>-<ordinal>; singleBinary.replicas = 1
    name      = "storage-loki-0"
    namespace = var.config.kps_namespace
  }
  labels = {
    "recurring-job.longhorn.io/source"                 = "enabled"
    "recurring-job-group.longhorn.io/no-recurring-job" = "enabled"
  }

  depends_on = [helm_release.this]
}
