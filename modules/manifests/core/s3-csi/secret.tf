## ============================================================================================= ##
#  modules/manifests/core/s3-csi/secret.tf                                                        #
#                                                                                                 #
#  Kubernetes Secret for application-sensitive data.                                              #
#  Add secret keys as needed for your application (passwords, tokens, keys).                      #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "garage_credentials" {
  metadata {
    name      = "garage-s3-credentials"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = {
    key_id     = var.secrets.access_key_id
    access_key = var.secrets.secret_access_key
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}
