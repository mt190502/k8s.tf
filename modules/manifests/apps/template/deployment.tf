## ============================================================================================= ##
#  modules/manifests/apps/template/deployment.tf                                                  #
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
            #~ For postgres
            # <<-EOT
            # until nc -zv ${var.config.name}-postgres-rw 5432; do
            #   echo "Waiting for PostgreSQL to be ready..."
            #   sleep 5
            # done
            # EOT

            #~ For mongo
            # <<-EOT
            # until nc -zv ${var.config.name}-mongo-rs0 27017; do
            #   echo "Waiting for MongoDB to be ready..."
            #   sleep 5
            # done
            # EOT
          ]
        }
        container {
          name  = var.config.name
          image = "${var.config.image}:${var.image_version}"
          dynamic "port" {
            for_each = var.config.port != null ? [var.config.port] : []
            content {
              container_port = port.value
            }
          }
          env {
            name = "SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.this[0].metadata[0].name
                key  = "changeme"
              }
            }
          }
          dynamic "env" {
            for_each = var.config.env != null ? var.config.env : {}
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.this
  ]
}