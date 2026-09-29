## ============================================================================================= ##
#  modules/manifests/apps/silverbullet/pvc.tf                                                     #
#                                                                                                 #
#  Notes live as plain Markdown files under /space. Any editor (including desktop Obsidian)       #
#  can open the same folder later.                                                                #
## ============================================================================================= ##
resource "kubernetes_persistent_volume_claim_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.config.storage_size
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.this]
}
