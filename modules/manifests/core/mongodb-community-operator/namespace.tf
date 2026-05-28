## ============================================================================================= ##
#  modules/manifests/core/mongodb-community-operator/namespace.tf                                 #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name = "mongodb-system"
  }
}
