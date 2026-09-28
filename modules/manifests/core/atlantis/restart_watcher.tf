## ============================================================================================= ##
#  modules/manifests/core/atlantis/restart_watcher.tf                                             #
## ============================================================================================= ##
resource "kubernetes_config_map_v1" "restart_watcher" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-restart-watcher"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    "restart_watcher.py" = file("${path.module}/restart_watcher.py")
  }
  depends_on = [kubernetes_namespace_v1.this]
}
