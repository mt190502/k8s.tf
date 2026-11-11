## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/pvc.tf                                            #
#                                                                                                 #
#  Adds the Prometheus TSDB PVC to the Longhorn "trim" recurring-job group, so the periodic       #
#  filesystem-trim job (core/longhorn/jobs) releases blocks freed by WAL truncation and           #
#  compaction. The PVC is already outside the default group (volumeClaimTemplate labels in        #
#  helm.tf), so no recurring job touched it and the volume grew to its full provisioned size      #
#  (plus any reboot-time system snapshot) on every replica node.                                  #
#                                                                                                 #
#  The label is set on the existing PVC: volumeClaimTemplate labels only reach newly created      #
#  PVCs, and changing them makes the operator recreate the StatefulSet. All three labels are      #
#  repeated here because with recurring-job.longhorn.io/source = enabled Longhorn syncs the       #
#  PVC's recurring-job labels to the volume and drops volume labels missing from the PVC.         #
#                                                                                                 #
#  The PVC is created by the operator after the chart is installed (helm wait = false), so        #
#  on a fresh install the first apply can fail here until the PVC exists; apply again.            #
## ============================================================================================= ##
resource "kubernetes_labels" "prometheus_db_pvc" {
  api_version = "v1"
  kind        = "PersistentVolumeClaim"
  metadata {
    name      = "prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  labels = {
    "recurring-job.longhorn.io/source"                 = "enabled"
    "recurring-job-group.longhorn.io/no-recurring-job" = "enabled"
    "recurring-job-group.longhorn.io/trim"             = "enabled"
  }
  depends_on = [helm_release.this]
}
