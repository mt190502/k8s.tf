resource "kubernetes_manifest" "certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "wildcard-mtaha.dev-tls"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      secretName = "wildcard-mtaha.dev-tls"
      secretTemplate = {
        annotations = {
          "reflector.v1.k8s.emberstack.com/reflection-allowed"            = "true"
          "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces" = "adguard-home,radicale"
          "reflector.v1.k8s.emberstack.com/reflection-auto-enabled"       = "true"
          "reflector.v1.k8s.emberstack.com/reflection-auto-namespaces"    = "adguard-home,radicale"
        }
      }
      dnsNames = [
        "mtaha.dev",
        "*.mtaha.dev"
      ]
      issuerRef = {
        name = kubernetes_manifest.clusterissuer.manifest.metadata.name
        kind = "ClusterIssuer"
      }
    }
  }

  depends_on = [
    helm_release.this
  ]
}