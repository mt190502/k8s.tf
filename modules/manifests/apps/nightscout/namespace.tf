## ============================================================================================= ##
#  modules/manifests/apps/nightscout/namespace.tf                                                 #
#                                                                                                 #
#  Namespace for the application - isolates resources within the cluster.                         #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.config.name
  }
}