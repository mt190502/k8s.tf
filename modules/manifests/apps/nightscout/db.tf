## ============================================================================================= ##
#  modules/manifests/apps/nightscout/db.tf                                                        #
#                                                                                                 #
#  PerconaServerMongoDB (PSMDB) cluster for Nightscout - 3-node replica set with persistent       #
#  storage. Uses databaseAdmin credentials from auto-generated secret.                            #
## ============================================================================================= ##
resource "kubernetes_manifest" "mongo" {
  manifest = {
    "apiVersion" = "psmdb.percona.com/v1"
    "kind"       = "PerconaServerMongoDB"
    "metadata" = {
      "name"      = "nightscout-mongo"
      "namespace" = kubernetes_namespace_v1.this.metadata[0].name
    }
    "spec" = {
      "crVersion"       = "1.22.0"
      "image"           = "percona/percona-server-mongodb:8.0.19-7"
      "imagePullPolicy" = "Always"
      "updateStrategy"  = "SmartUpdate"
      "secrets" = {
        "users"         = "nightscout-mongo-users"
        "encryptionKey" = "nightscout-mongo-encryption-key"
      }
      "replsets" = [
        {
          "name" = "rs0"
          "size" = 3
          "affinity" = {
            "antiAffinityTopologyKey" = "kubernetes.io/hostname"
          }
          "resources" = {
            "limits" = {
              "cpu"    = "1"
              "memory" = "1Gi"
            }
            "requests" = {
              "cpu"    = "300m"
              "memory" = "512Mi"
            }
          }
          "volumeSpec" = {
            "persistentVolumeClaim" = {
              "resources" = {
                "requests" = {
                  "storage" = "2Gi"
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