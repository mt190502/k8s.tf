## ============================================================================================= ##
#  modules/manifests/core/testing/namespace.tf                                                    #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "testing_namespace" {
  metadata {
    name = "testing"
  }
}