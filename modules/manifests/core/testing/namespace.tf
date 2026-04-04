## ============================================================================================= ##
#  modules/manifests/core/testing/namespace.tf                                                    #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "testing_namespace" {
  count = var.enabled ? 1 : 0
  metadata {
    name = "testing"
  }
}