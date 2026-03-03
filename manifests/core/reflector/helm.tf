resource "helm_release" "this" {
  name            = "reflector"
  repository      = "https://emberstack.github.io/helm-charts"
  version         = "10.0.10"
  chart           = "reflector"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  values = [
    <<-EOF
      cron:
        schedule: "*/15 * * * *"
    EOF
  ]

  depends_on = [
    kubernetes_namespace_v1.this
  ]
}
