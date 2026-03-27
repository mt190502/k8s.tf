## ============================================================================================= ##
#  modules/manifests/apps/nightscout/namespace.tf                                                 #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "nightscout"
  }
}
