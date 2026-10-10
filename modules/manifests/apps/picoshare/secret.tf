## ============================================================================================= ##
#  modules/manifests/apps/picoshare/secret.tf                                                     #
#                                                                                                 #
#  Kubernetes Secret for application-sensitive data.                                              #
#  Required keys:                                                                                 #
#    shared_secret --- Passphrase for the PicoShare admin user (PS_SHARED_SECRET)                 #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-secret"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data       = var.secrets
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}
