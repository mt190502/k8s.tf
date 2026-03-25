## ============================================================================================= ##
#  modules/manifests/core/tailscale-operator/secret.tf                                            #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "operator_oauth" {
  metadata {
    name      = "operator-oauth"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = {
    client_id     = var.secrets.client_id
    client_secret = var.secrets.client_secret
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_secret_v1" "tailscale_auth" {
  metadata {
    name      = "tailscale-auth"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = {
    TS_AUTH_KEY = var.secrets.auth_key
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}