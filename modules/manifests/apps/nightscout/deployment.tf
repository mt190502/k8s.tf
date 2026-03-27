## ============================================================================================= ##
#  modules/manifests/apps/nightscout/deployment.tf                                                #
#                                                                                                 #
#  Deployment for Nightscout (CGM data visualization app) with MongoDB connection.                #
#  Uses PSMDB for database storage and cert-manager Gateway for ingress.                          #
## ============================================================================================= ##
resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = "nightscout"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "nightscout"
    }
  }
  spec {
    replicas = var.config.replicas
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "nightscout"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "nightscout"
        }
      }
      spec {
        init_container {
          name  = "nightscout-init"
          image = "busybox"
          command = [
            "sh",
            "-c",
            <<-EOT
            until nc -zv nightscout-mongo-rs0.nightscout.svc.cluster.local 27017; do
              echo "Waiting for MongoDB to be ready..."
              sleep 5
            done
            EOT
          ]
        }
        container {
          name  = "nightscout"
          image = "nightscout/cgm-remote-monitor:${var.image_version}"
          port {
            container_port = 1337
          }
          dynamic "env" {
            for_each = var.config.env
            content {
              name  = env.key
              value = env.value
            }
          }
          env {
            name = "API_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.this.metadata[0].name
                key  = "api_secret"
              }
            }
          }
          env {
            name = "MONGO_PASSWORD"
            value_from {
              secret_key_ref {
                name = "nightscout-mongo-users"
                key  = "MONGODB_DATABASE_ADMIN_PASSWORD"
              }
            }
          }
          env {
            name = "MONGO_USER"
            value_from {
              secret_key_ref {
                name = "nightscout-mongo-users"
                key  = "MONGODB_DATABASE_ADMIN_USER"
              }
            }
          }
          env {
            name  = "MONGO_CONNECTION"
            value = "mongodb://$(MONGO_USER):$(MONGO_PASSWORD)@nightscout-mongo-rs0.nightscout.svc.cluster.local:27017/nightscout?replicaSet=rs0&authSource=admin"
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.this,
    kubernetes_manifest.mongo
  ]
}