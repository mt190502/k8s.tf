resource "helm_release" "this" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  version         = "82.1.0"
  chart           = "kube-prometheus-stack"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  wait            = false
  upgrade_install = true
  depends_on = [
    kubernetes_namespace_v1.this
  ]
}
