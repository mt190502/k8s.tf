resource "helm_release" "this" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = "3.9.1"
  namespace        = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install  = true
  create_namespace = false
  set = [
    { name = "admissionController.replicas", value = "3", },
    { name = "admissionController.serviceMonitor.enabled", value = true, },
    { name = "backgroundController.replicas", value = "2", },
    { name = "backgroundController.serviceMonitor.enabled", value = true, },
    { name = "cleanupController.replicas", value = "2", },
    { name = "cleanupController.serviceMonitor.enabled", value = true, },
    { name = "grafana.enabled", value = true, },
    { name = "reportsController.replicas", value = "2", },
    { name = "reportsController.serviceMonitor.enabled", value = true, }
  ]

  depends_on = [kubernetes_namespace_v1.this]
}
