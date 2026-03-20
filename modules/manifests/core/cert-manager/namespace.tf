## ============================================================================================= ##
#  modules/manifests/core/cert-manager/namespace.tf                                               #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "cert-manager"
  }
}
