## ============================================================================================= ##
#  modules/manifests/apps/template/secret.tf                                                      #
#                                                                                                 #
#  Kubernetes Secret for application-sensitive data.                                              #
#  Add secret keys as needed for your application (passwords, tokens, keys).                      #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "this" {
  metadata {
    name      = "${var.config.name}-secret"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data       = var.secrets
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}