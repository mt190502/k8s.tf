resource "helm_release" "this" {
  name       = "longhorn"
  repository = "https://charts.longhorn.io"
  version    = "1.11.0"
  chart      = "longhorn"
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  values = [
    <<-EOF
      preUpgradeChecker:
        jobEnabled: false
      longhornUI:
        replicas: 3
    EOF
  ]

  depends_on = [
    kubernetes_namespace_v1.this
  ]
}
