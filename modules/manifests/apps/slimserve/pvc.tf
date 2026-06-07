## ============================================================================================= ##
#  modules/manifests/apps/slimserve/pvc.tf                                                        #
#                                                                                                 #
#  PersistentVolumeClaim for applications requiring persistent storage.                           #
#  Mount this PVC in Deployment/StatefulSet containers.                                           #
## ============================================================================================= ##
resource "kubernetes_persistent_volume_claim_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-pvc"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = ""
    resources {
      requests = {
        storage = var.config.persistence.storage_size
      }
    }
    volume_name = kubernetes_persistent_volume_v1.this[0].metadata[0].name
  }
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_persistent_volume_v1.this,
  ]
}