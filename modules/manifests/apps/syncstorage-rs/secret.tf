## ============================================================================================= ##
#  modules/manifests/apps/syncstorage-rs/secret.tf                                                #
#                                                                                                 #
#  Kubernetes Secret for application-sensitive data.                                              #
#  Includes master_secret and constructed database URLs.                                          #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-secret"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = merge(
    var.secrets.app,
    {
      syncstorage_database_url = "postgres://${var.config.name}:${try(var.secrets.pg.password, "changeme")}@${var.config.name}-postgres-rw:5432/${var.config.name}"
      tokenserver_database_url = "postgres://${var.config.name}:${try(var.secrets.pg.password, "changeme")}@${var.config.name}-postgres-rw:5432/${var.config.name}"
    }
  )
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}