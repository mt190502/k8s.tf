## ============================================================================================= ##
#  modules/manifests/apps/gotify/secret.tf                                                        #
#                                                                                                 #
#  Kubernetes Secret for application-sensitive data.                                              #
#  Add secret keys as needed for your application (passwords, tokens, keys).                      #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-secret"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data       = var.secrets.app
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_secret_v1" "gotify_bridge" {
  count = var.enabled && try(var.secrets.bridge.gotify_token, "") != "" ? 1 : 0
  metadata {
    name      = "alertmanager-${var.config.name}-bridge-secret"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    gotify_token = var.secrets.bridge.gotify_token
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}