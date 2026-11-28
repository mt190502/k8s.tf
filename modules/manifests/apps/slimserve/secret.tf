## ============================================================================================= ##
#  modules/manifests/apps/slimserve/secret.tf                                                     #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "s3_credentials" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-s3-credentials"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    AWS_ACCESS_KEY_ID     = var.secrets.access_key_id
    AWS_SECRET_ACCESS_KEY = var.secrets.secret_access_key
    RELEASE_COOKIE        = var.secrets.release_cookie
    SECRET_KEY_BASE       = var.secrets.secret_key_base
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}
