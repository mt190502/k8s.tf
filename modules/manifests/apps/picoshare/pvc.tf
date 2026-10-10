## ============================================================================================= ##
#  modules/manifests/apps/picoshare/pvc.tf                                                        #
#                                                                                                 #
#  PersistentVolumeClaim holding the PicoShare SQLite database (all shared content lives in it).   #
#  The default StorageClass (longhorn) allows online expansion, so start small and grow when       #
#  the retention window fills the volume.                                                          #
## ============================================================================================= ##
resource "kubernetes_persistent_volume_claim_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-pvc"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.config.storage_size == null ? "4Gi" : var.config.storage_size
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.this]
}
