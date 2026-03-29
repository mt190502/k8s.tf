## ============================================================================================= ##
#  modules/manifests/apps/nightscout/deployment.tf                                                #
#                                                                                                 #
#  Deployment for stateless applications - manages replica pods with rolling updates.             #
#  Uses environment variables from config and secrets from Kubernetes Secret.                     #
## ============================================================================================= ##
resource "kubernetes_deployment_v1" "this" {
  count = var.config.replicas != null ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = var.config.name
    }
  }
  spec {
    replicas = var.config.replicas
    selector {
      match_labels = {
        "app.kubernetes.io/name" = var.config.name
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = var.config.name
        }
      }
      spec {
        init_container {
          name  = "${var.config.name}-init"
          image = "busybox"
          command = [
            "sh",
            "-c",
            <<-EOT
            until nc -zv ${var.config.name}-mongo-rs0 27017; do
              echo "Waiting for MongoDB to be ready..."
              sleep 5
            done
            EOT
          ]
        }
        container {
          name  = var.config.name
          image = "${var.config.image}:${var.image_version}"
          port {
            container_port = var.config.port
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
                name = "${var.config.name}-mongo-users"
                key  = "MONGODB_DATABASE_ADMIN_PASSWORD"
              }
            }
          }
          env {
            name = "MONGO_USER"
            value_from {
              secret_key_ref {
                name = "${var.config.name}-mongo-users"
                key  = "MONGODB_DATABASE_ADMIN_USER"
              }
            }
          }
          env {
            name  = "MONGO_CONNECTION"
            value = "mongodb://$(MONGO_USER):$(MONGO_PASSWORD)@${var.config.name}-mongo-rs0:27017/${var.config.name}?replicaSet=rs0&authSource=admin"
          }
          dynamic "env" {
            for_each = var.config.env != null ? var.config.env : {}
            content {
              name  = env.key
              value = env.value
            }
          }
          dynamic "resources" {
            for_each = var.config.resources != null ? [1] : []
            content {
              limits = (var.config.resources.limits != null || var.config.resources.limits != {}) ? var.config.resources.limits : ((var.config.resources.requests == null || var.config.resources.requests == {}) ? {
                cpu    = "1"
                memory = "1Gi"
              } : {})
              requests = (var.config.resources.requests != null || var.config.resources.requests != {}) ? var.config.resources.requests : ((var.config.resources.limits == null || var.config.resources.limits == {}) ? {
                cpu    = "500m"
                memory = "512Mi"
              } : {})
            }
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