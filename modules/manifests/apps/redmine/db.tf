## ============================================================================================= ##
#  modules/manifests/apps/redmine/db.tf                                                           #
#                                                                                                 #
#  CloudNativePG (CNPG) PostgreSQL cluster - managed by cnpg operator.                            #
#  Requires cnpg-operator to be installed. Creates database with owner credentials                #
#  from the provided secret.                                                                      #
#                                                                                                 #
#  Connection string format:                                                                      #
#    postgresql://{owner}:{password}@{app}-postgres-rw.{namespace}.svc.cluster.local:5432/{db}    #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "postgres" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-postgres-secret"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    database = var.config.name
    username = var.config.name
    password = try(var.secrets.pg.password, "changeme")
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_manifest" "postgres" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = "${var.config.name}-postgres"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      instances             = var.config.pg.replicas
      primaryUpdateStrategy = "unsupervised"
      bootstrap = {
        initdb = {
          database = var.config.name
          owner    = var.config.name
          secret = {
            name = kubernetes_secret_v1.postgres[0].metadata[0].name
          }
        }
      }
      resources = {
        limits = var.config.pg.limits == null ? {
          cpu    = "500m"
          memory = "512Mi"
        } : var.config.pg.limits
        requests = var.config.pg.requests == null ? {
          cpu    = "250m"
          memory = "256Mi"
        } : var.config.pg.requests
      }
      storage = {
        size = var.config.pg.storage_size == null ? "1Gi" : var.config.pg.storage_size
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.this, kubernetes_secret_v1.postgres]
}