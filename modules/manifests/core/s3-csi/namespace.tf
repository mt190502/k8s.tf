## ============================================================================================= ##
#  modules/manifests/core/s3-csi/namespace.tf                                                     #
#                                                                                                 #
#  Namespace for the application - isolates resources within the cluster.                         #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "s3-csi-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}