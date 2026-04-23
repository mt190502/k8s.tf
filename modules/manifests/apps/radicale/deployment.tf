## ============================================================================================= ##
#  modules/manifests/apps/radicale/deployment.tf                                                  #
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
          image = "tomsquest/docker-radicale:3.7.1.0"
          command = [
            "sh",
            "-c",
            <<-EOT
              if [ -f /app/data/users ]; then
                echo "User file already exists, skipping user initialization"
                exit 0
              fi
              apk add apache2-utils
              htpasswd -b -c /app/data/users $(cat /app/secret/username) $(cat /app/secret/password)
            EOT
          ]
          volume_mount {
            name       = "${var.config.name}-data"
            mount_path = "/app/data"
          }
          volume_mount {
            name       = "${var.config.name}-config"
            mount_path = "/app/config"
          }
          volume_mount {
            name       = "${var.config.name}-secret"
            mount_path = "/app/secret"
          }
        }
        container {
          name  = var.config.name
          image = "tomsquest/docker-radicale:3.7.1.0"
          command = [
            "sh",
            "-c",
            <<-EOT
              /venv/bin/radicale --config $(ls /app/config | sed 's|^|/app/config/|' | paste -sd ":" -)
            EOT
          ]
          port {
            container_port = var.config.port
          }
          dynamic "resources" {
            for_each = var.config.resources != null ? [1] : []
            content {
              limits = (var.config.resources.limits != null || var.config.resources.limits != {}) ? var.config.resources.limits : ((var.config.resources.requests == null || var.config.resources.requests == {}) ? {
                cpu    = "250m"
                memory = "512Mi"
              } : {})
              requests = (var.config.resources.requests != null || var.config.resources.requests != {}) ? var.config.resources.requests : ((var.config.resources.limits == null || var.config.resources.limits == {}) ? {
                cpu    = "125m"
                memory = "256Mi"
              } : {})
            }
          }
          volume_mount {
            name       = "${var.config.name}-data"
            mount_path = "/app/data"
          }
          volume_mount {
            name       = "${var.config.name}-config"
            mount_path = "/app/config"
          }
          volume_mount {
            name       = "${var.config.name}-ssl"
            mount_path = "/app/ssl"
          }
          volume_mount {
            name       = "${var.config.name}-secret"
            mount_path = "/app/secret"
          }
        }
        volume {
          name = "${var.config.name}-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.this[0].metadata[0].name
          }
        }
        volume {
          name = "${var.config.name}-config"
          config_map {
            name = kubernetes_config_map_v1.configmap[0].metadata[0].name
          }
        }
        volume {
          name = "${var.config.name}-ssl"
          secret {
            secret_name = var.config.certificate_name
          }
        }
        volume {
          name = "${var.config.name}-secret"
          secret {
            secret_name = kubernetes_secret_v1.this[0].metadata[0].name
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