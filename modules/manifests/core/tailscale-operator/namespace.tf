## ============================================================================================= ##
#  modules/manifests/core/tailscale-operator/namespace.tf                                         #
## ============================================================================================= ##
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "tailscale-system"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}
