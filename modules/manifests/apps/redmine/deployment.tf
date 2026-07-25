## ============================================================================================= ##
#  modules/manifests/apps/redmine/deployment.tf                                                   #
#                                                                                                 #
#  Deployment for stateless applications - manages replica pods with rolling updates.             #
#  Uses environment variables from config and secrets from Kubernetes Secret.                     #
## ============================================================================================= ##
resource "kubernetes_deployment_v1" "this" {
  count = (var.enabled && var.config.replicas != null) ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
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
          image = "busybox:latest"
          command = [
            "sh",
            "-c",
            <<-EOT
            until nc -zv ${var.config.name}-postgres-rw 5432; do
              echo "Waiting for PostgreSQL to be ready..."
              sleep 5
            done
            EOT
          ]
        }
        container {
          name  = var.config.name
          image = "redmine:7.0.0"
          port {
            container_port = var.config.port
          }
          env {
            name = "REDMINE_DB_DATABASE"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres[0].metadata[0].name
                key  = "database"
              }
            }
          }
          env {
            name = "REDMINE_DB_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres[0].metadata[0].name
                key  = "username"
              }
            }
          }
          env {
            name = "REDMINE_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres[0].metadata[0].name
                key  = "password"
              }
            }
          }
          env {
            name  = "REDMINE_DB_POSTGRES"
            value = "${var.config.name}-postgres-rw"
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
          volume_mount {
            name       = "${var.config.name}-data"
            mount_path = "/usr/src/redmine/files"
            sub_path   = "files"
          }
          volume_mount {
            name       = "${var.config.name}-data"
            mount_path = "/usr/src/redmine/plugins"
            sub_path   = "plugins"
          }
          volume_mount {
            name       = "${var.config.name}-data"
            mount_path = "/usr/src/redmine/themes"
            sub_path   = "themes"
          }
        }
        volume {
          name = "${var.config.name}-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.this[0].metadata[0].name
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_manifest.postgres
  ]
}