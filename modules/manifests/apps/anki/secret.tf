## ============================================================================================= ##
#  modules/manifests/apps/anki/secret.tf                                                          #
#                                                                                                 #
#  Kubernetes Secret for application-sensitive data.                                              #
#  Creates ACCOUNT entries for each sync user account.                                            #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-secret"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data       = { for idx, account in try(var.secrets.app.accounts, []) : "ACCOUNT${idx + 1}" => "${account.username}:${account.password}" }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}