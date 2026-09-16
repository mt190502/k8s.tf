## ============================================================================================= ##
#  Kubernetes Secret for HedgeDoc application-sensitive data.                                     #
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
