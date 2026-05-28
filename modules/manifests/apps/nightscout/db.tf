## ============================================================================================= ##
#  modules/manifests/apps/nightscout/db.tf                                                        #
#                                                                                                 #
#  MongoDB Community Operator                                                                     #
#  Requires mongodb community operator to be installed. Uses credentials from                     #
#  the provided secret.                                                                           #
#                                                                                                 #
#  Connection string format:                                                                      #
#    mongodb://databaseAdmin:{password}@{app}-mongo-svc.{namespace}.svc.cluster.local:27017/{db}  #
## ============================================================================================= ##
locals {
  mongodb_name      = "${var.config.name}-mongo"
  mongodb_namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  mongodb = yamlencode({
    apiVersion = "mongodbcommunity.mongodb.com/v1"
    kind       = "MongoDBCommunity"
    metadata = {
      name      = local.mongodb_name
      namespace = local.mongodb_namespace
    }
    spec = {
      members                     = try(var.config.mongo.replicas, var.config.replicas)
      type                        = "ReplicaSet"
      version                     = "8.0.0"
      featureCompatibilityVersion = "8.0"
      security = {
        authentication = {
          modes = ["SCRAM"]
        }
      }
      users = [
        {
          name = "${var.config.name}"
          db   = var.config.name
          passwordSecretRef = {
            name = kubernetes_secret_v1.mongo_password[0].metadata[0].name
          }
          roles = [
            {
              name = "readWrite"
              db   = var.config.name
            },
            {
              name = "dbAdmin"
              db   = var.config.name
            }
          ]
          scramCredentialsSecretName = "${var.config.name}-mongo-scram"
          connectionStringSecretName = "${var.config.name}-mongo-conn"
        }
      ]
      memberConfig = [
        {
          votes = 1
        },
        {
          votes = 1
        }
      ]
      statefulSet = {
        spec = {
          template = {
            spec = {
              serviceAccountName = kubernetes_service_account_v1.mongodb_database[0].metadata[0].name
              containers = [
                {
                  name = "mongod"
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
                }
              ]
            }
          }
          volumeClaimTemplates = [
            {
              metadata = {
                name = "data-volume"
              }
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.config.mongo.storage_size == null ? "1Gi" : var.config.mongo.storage_size
                  }
                }
              }
            }
          ]
        }
      }
    }
  })
}

resource "kubernetes_service_account_v1" "mongodb_database" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "mongodb-database"
    namespace = local.mongodb_namespace
  }
  automount_service_account_token = true
}

resource "kubernetes_role_v1" "mongodb_database" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "mongodb-database"
    namespace = local.mongodb_namespace
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["patch", "delete", "get"]
  }
}

resource "kubernetes_role_binding_v1" "mongodb_database" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "mongodb-database"
    namespace = local.mongodb_namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.mongodb_database[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.mongodb_database[0].metadata[0].name
    namespace = local.mongodb_namespace
  }
}

data "external" "mongodb_exists" {
  program = [
    "bash",
    "-c",
    "kubectl get mongodbcommunity ${local.mongodb_name} -n ${local.mongodb_namespace} >/dev/null 2>&1 && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'",
  ]
}

resource "null_resource" "mongodb" {
  triggers = {
    name         = local.mongodb_name
    namespace    = local.mongodb_namespace
    manifest_sha = sha256(local.mongodb)
    exists       = data.external.mongodb_exists.result.exists
  }
  provisioner "local-exec" {
    command = "kubectl apply -f - <<EOF\n${local.mongodb}\nEOF"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "[ \"true\" = \"${self.triggers.exists}\" ] && kubectl delete mongodbcommunity ${self.triggers.name} -n ${self.triggers.namespace} --ignore-not-found=true || true"
  }
  depends_on = [kubernetes_secret_v1.mongo_password, kubernetes_service_account_v1.mongodb_database, kubernetes_role_binding_v1.mongodb_database]
}


resource "kubernetes_secret_v1" "mongo_password" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-mongo-password"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    password = try(var.secrets.mongo.password, "changeme")
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}