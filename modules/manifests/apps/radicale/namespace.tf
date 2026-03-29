## ============================================================================================= ##
#  modules/manifests/apps/radicale/namespace.tf                                                   #
#                                                                                                 #
#  Namespace for the application - isolates resources within the cluster.                         #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name = var.config.name
  }
}