## ============================================================================================= ##
#  modules/manifests/core/atlantis/namespace.tf                                                   #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name = "${var.config.name}-system"
  }
}