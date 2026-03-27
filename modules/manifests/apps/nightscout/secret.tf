## ============================================================================================= ##
#  modules/manifests/apps/nightscout/secret.tf                                                    #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "this" {
  metadata {
    name      = "api-secret"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = {
    api_secret = var.secrets.api_secret
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}