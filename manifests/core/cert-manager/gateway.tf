resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "gateway"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = kubernetes_manifest.clusterissuer.manifest.metadata.name
      }
    }
    spec = {
      gatewayClassName = "cilium"
      listeners = [
        {
          name     = "websecure"
          port     = 443
          protocol = "HTTPS"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                name      = kubernetes_secret_v1.this.metadata[0].name
                namespace = kubernetes_namespace_v1.this.metadata[0].name
              }
            ]
          }
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.clusterissuer,
    kubernetes_manifest.certificate
  ]
}