## ============================================================================================= ##
#  modules/manifests/core/renovate/pvc.tf                                                         #
#                                                                                                 #
#  PersistentVolumeClaim for the Renovate cache.                                                  #
#  Caches datasource responses and (for the default image) runtime-installed toolchains.          #
## ============================================================================================= ##
resource "kubernetes_persistent_volume_claim_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-cache"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
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
