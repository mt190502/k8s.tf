## ============================================================================================= ##
#  modules/manifests/core/longhorn/secret.tf                                                      #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "longhorn_s3_credentials" {
  metadata {
    name      = "longhorn-s3-credentials"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = {
    "AWS_ACCESS_KEY_ID"     = var.secrets.access_key_id
    "AWS_ENDPOINTS"         = var.secrets.endpoints
    "AWS_SECRET_ACCESS_KEY" = var.secrets.secret_access_key
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}