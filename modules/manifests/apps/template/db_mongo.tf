## ============================================================================================= ##
#  modules/manifests/apps/template/db_mongo.tf                                                    #
#                                                                                                 #
#  PerconaServerMongoDB (PSMDB) cluster                                                           #
#  Requires psmdb-operator to be installed. Uses databaseAdmin credentials from                   #
#  auto-generated secret.                                                                         #
#                                                                                                 #
#  Connection string format:                                                                      #
#    mongodb://databaseAdmin:{password}@{app}-mongo-rs0.{namespace}.svc.cluster.local:27017/{db}  #
#    ?replicaSet=rs0&authSource=admin                                                             #
## ============================================================================================= ##
resource "kubernetes_manifest" "mongo" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "psmdb.percona.com/v1"
    kind       = "PerconaServerMongoDB"
    metadata = {
      name      = "${var.config.name}-mongo"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      crVersion       = "1.22.0"
      image           = "percona/percona-server-mongodb:8.0.19-7"
      imagePullPolicy = "Always"
      updateStrategy  = "SmartUpdate"
      secrets = {
        users         = "${var.config.name}-mongo-users"
        encryptionKey = "${var.config.name}-mongo-encryption-key"
      }
      replsets = [
        {
          name = "rs0"
          size = try(var.config.mongo.replicas, var.config.replicas)
          affinity = {
            antiAffinityTopologyKey = "kubernetes.io/hostname"
          }
          resources = {
            limits = var.config.mongo.limits == null ? {
              cpu    = "500m"
              memory = "512Mi"
            } : var.config.mongo.limits
            requests = var.config.mongo.requests == null ? {
              cpu    = "250m"
              memory = "256Mi"
            } : var.config.mongo.requests
          }
          volumeSpec = {
            persistentVolumeClaim = {
              resources = {
                requests = {
                  storage = var.config.mongo.storage_size == null ? "1Gi" : var.config.mongo.storage_size
                }
              }
            }
          }
        }
      ]
    }
  }
  depends_on = [kubernetes_namespace_v1.this]
}