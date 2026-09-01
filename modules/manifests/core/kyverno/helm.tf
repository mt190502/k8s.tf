resource "helm_release" "this" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = "3.9.0"
  namespace        = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install  = true
  create_namespace = false
  set = [
    {
      name  = "admissionController.replicas"
      value = "3"
    },
    {
      name  = "backgroundController.replicas"
      value = "2"
    },
    {
      name  = "cleanupController.replicas"
      value = "2"
    },
    {
      name  = "reportsController.replicas"
      value = "2"
    }
  ]

  depends_on = [kubernetes_namespace_v1.this]
}
