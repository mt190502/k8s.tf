## ============================================================================================= ##
#  modules/manifests/settings/ci/configmap.tf                                                     #
## ============================================================================================= ##
data "kubernetes_config_map_v1" "kube_root_ca" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "kube-root-ca.crt"
    namespace = "kube-system"
  }
  depends_on = [kubernetes_service_account_v1.ci]
}