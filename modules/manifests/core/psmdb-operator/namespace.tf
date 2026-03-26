## ============================================================================================= ##
#  modules/manifests/core/psmdb-operator/namespace.tf                                             #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "psmdb-system"
  }
}
