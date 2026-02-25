resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "gateway"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = local.clusterissuer_name
      }
    }
    spec = {
      gatewayClassName = "cilium"
      listeners = [
        {
          name     = "websecure"
          hostname = "*.mtaha.dev"
          port     = 443
          protocol = "HTTPS"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                name      = local.certificate_name
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
    null_resource.clusterissuer,
    null_resource.certificate
  ]
}