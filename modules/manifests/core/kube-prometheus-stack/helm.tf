## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/helm.tf                                           #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  version         = var.chart_version
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  wait            = false
  upgrade_install = true
  depends_on      = [kubernetes_namespace_v1.this]
}
