## ============================================================================================= ##
#  modules/manifests/apps/template/pvc.tf                                                         #
#                                                                                                 #
#  PersistentVolumeClaim for applications requiring persistent storage.                           #
#  Mount this PVC in Deployment/StatefulSet containers.                                           #
## ============================================================================================= ##
resource "kubernetes_persistent_volume_claim_v1" "this" {
  metadata {
    name      = "${var.config.name}-pvc"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.config.storage_size == null ? "1Gi" : var.config.storage_size
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.this]
}