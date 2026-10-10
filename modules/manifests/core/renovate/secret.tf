## ============================================================================================= ##
#  modules/manifests/core/renovate/secret.tf                                                      #
#                                                                                                 #
#  Kubernetes Secret for application-sensitive data.                                              #
#  Required keys:                                                                                 #
#    app-id               --- GitHub App ID                                                       #
#    app-installation-id  --- GitHub App installation ID (App installed on the target account)     #
#    app-private-key      --- GitHub App private key (PEM)                                        #
#    github-com-token     --- Read-only PAT used to fetch changelogs/release notes (rate limits)   #
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
