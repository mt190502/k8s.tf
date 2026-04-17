## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/helm.tf                                           #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  version         = "83.6.0"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  wait            = false
  upgrade_install = true
  values = [yamlencode({
    grafana = {
      persistence = {
        enabled = true
        type    = "pvc"
        size    = "1Gi"
      }
    }
  })]
  depends_on = [kubernetes_namespace_v1.this]
}
