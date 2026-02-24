resource "kubernetes_manifest" "clusterissuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "mainissuer"
    }
    spec = {
      acme = {
        email  = "mt190502@mtaha.dev"
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "issuer-account-key"
        }
        solvers = [
          {
            dns01 = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = kubernetes_secret_v1.this.metadata[0].name
                  key  = "cf-api-token"
                }
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [
    helm_release.this
  ]
}