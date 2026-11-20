## ============================================================================================= ##
#  modules/manifests/core/renovate/pvc.tf                                                         #
#                                                                                                 #
#  PersistentVolumeClaim for the Renovate cache.                                                  #
#  Caches datasource responses and (for the default image) runtime-installed toolchains.          #
#  The volume holds only cache data that Renovate rebuilds on demand, so it opts out of           #
#  the Longhorn "default" recurring-job group and into the "trim" group instead: nightly          #
#  snapshots pinned every run and grew the 1.1Gi volume to 1.8G on every replica node             #
#  (same as the trivy server cache; core/longhorn/jobs trims the group every six hours).          #
## ============================================================================================= ##
resource "kubernetes_persistent_volume_claim_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-cache"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    labels = {
      "recurring-job.longhorn.io/source"                 = "enabled"
      "recurring-job-group.longhorn.io/no-recurring-job" = "enabled"
      "recurring-job-group.longhorn.io/trim"             = "enabled"
    }
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.config.storage_class
    resources {
      requests = {
        storage = var.config.storage_size == null ? "2Gi" : var.config.storage_size
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.this]
}
