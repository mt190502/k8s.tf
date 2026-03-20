## ============================================================================================= ##
#  modules/manifests/core/cert-manager/secret.tf                                                  #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "this" {
  metadata {
    name      = "cert-manager-cf-key"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = {
    "cf-api-token" = var.secrets.api_token
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}
