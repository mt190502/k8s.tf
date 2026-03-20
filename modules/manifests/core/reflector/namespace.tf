## ============================================================================================= ##
#  modules/manifests/core/reflector/namespace.tf                                                  #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "reflector-system"
  }
}
