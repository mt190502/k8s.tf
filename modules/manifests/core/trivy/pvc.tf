## ============================================================================================= ##
#  modules/manifests/core/trivy/pvc.tf                                                            #
#                                                                                                 #
#  Opts the built-in trivy server PVC out of the Longhorn "default" recurring-job group, so       #
#  the nightly-snapshot and monthly-backup jobs skip it (same pattern as the Loki and Prometheus  #
#  PVCs). The PVC only caches the vulnerability DB, which the server re-downloads on its own;     #
#  snapshots of it pinned every DB update and grew the volume past its size on each replica.      #
#  The "trim" group enables the weekly filesystem-trim job (core/longhorn/jobs), so blocks of     #
#  replaced DB files are released and the volume stays near its filesystem usage.                 #
#                                                                                                 #
#  The labels are set on the existing PVC: the chart exposes no volumeClaimTemplate labels and    #
#  changes to StatefulSet volumeClaimTemplates are forbidden. With                                #
#  recurring-job.longhorn.io/source = enabled, Longhorn syncs the PVC's recurring-job labels      #
#  to the volume and removes its "default" group label. Destroying this resource only unlabels    #
#  the PVC: the volume keeps the "trim" group and stays out of "default" until relabelled.        #
## ============================================================================================= ##
resource "kubernetes_labels" "trivy_server_pvc" {
  count = var.config.built_in_trivy_server ? 1 : 0

  api_version = "v1"
  kind        = "PersistentVolumeClaim"
  metadata {
    name      = "data-trivy-server-0"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  labels = {
    "recurring-job.longhorn.io/source"                 = "enabled"
    "recurring-job-group.longhorn.io/no-recurring-job" = "enabled"
    "recurring-job-group.longhorn.io/trim"             = "enabled"
  }

  depends_on = [helm_release.this]
}
