## ============================================================================================= ##
#  modules/manifests/core/gotify/secret.tf                                                        #
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

#~ bridge secret generator
resource "kubernetes_secret_v1" "bridge" {
  for_each = toset(nonsensitive(keys(var.secrets.bridges)))
  metadata {
    name      = "${each.key}-${var.config.name}-bridge-secret"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    gotify_token = var.secrets.bridges[each.key].token
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}