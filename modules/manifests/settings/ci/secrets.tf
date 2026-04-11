## ============================================================================================= ##
#  modules/manifests/settings/ci/secrets.tf                                                       #
## ============================================================================================= ##
data "kubernetes_secret_v1" "ci_token" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = kubernetes_secret_v1.ci_token[0].metadata[0].name
    namespace = var.config.namespace
  }
  depends_on = [kubernetes_secret_v1.ci_token]
}

resource "kubernetes_secret_v1" "ci_token" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.service_account_name}-token"
    namespace = var.config.namespace
    annotations = {
      "kubernetes.io/service-account.name" = var.config.service_account_name
    }
  }
  type       = "kubernetes.io/service-account-token"
  depends_on = [kubernetes_service_account_v1.ci]
}