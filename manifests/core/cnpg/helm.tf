resource "helm_release" "this" {
  name            = "cloudnative-pg"
  repository      = "https://cloudnative-pg.github.io/charts"
  version         = "0.27.1"
  chart           = "cloudnative-pg"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  values = [
    <<-EOF
      replicaCount: 3
    EOF
  ]

  depends_on = [
    kubernetes_namespace_v1.this
  ]
}
