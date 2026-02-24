resource "helm_release" "this" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.19.3"
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  values = [
    <<-EOF
      installCRDs: true
      config:
        apiVersion: controller.config.cert-manager.io/v1alpha1
        kind: ControllerConfiguration
        enableGatewayAPI: true
      extraArgs:
        - --enable-certificate-owner-ref=true
        - --dns01-recursive-nameservers-only
        - --dns01-recursive-nameservers=1.1.1.1:53,9.9.9.9:53
      prometheus:
        enabled: true
        servicemonitor:
          enabled: true
    EOF
  ]

  depends_on = [
    kubernetes_secret_v1.this
  ]
}