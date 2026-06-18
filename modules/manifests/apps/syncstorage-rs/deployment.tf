## ============================================================================================= ##
#  modules/manifests/apps/syncstorage-rs/deployment.tf                                            #
#                                                                                                 #
#  Deployment for syncstorage-rs - Mozilla Firefox Sync server.                                   #
#  Requires CNPG PostgreSQL for data storage.                                                     #
#  Image: ghcr.io/mozilla-services/syncstorage-rs/syncserver-postgres                             #
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
          image = "ghcr.io/mozilla-services/syncstorage-rs/syncserver-postgres:0.23.3"
          port {
            container_port = var.config.port
          }
          env {
            name  = "SYNC_HOST"
            value = "0.0.0.0"
          }
          env {
            name  = "SYNC_PORT"
            value = tostring(var.config.port)
          }
          env {
            name = "SYNC_MASTER_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.this[0].metadata[0].name
                key  = "master_secret"
              }
            }
          }
          env {
            name = "SYNC_SYNCSTORAGE__DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.this[0].metadata[0].name
                key  = "syncstorage_database_url"
              }
            }
          }
          env {
            name = "SYNC_TOKENSERVER__DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.this[0].metadata[0].name
                key  = "tokenserver_database_url"
              }
            }
          }
          env {
            name  = "SYNC_TOKENSERVER__ENABLED"
            value = "true"
          }
          env {
            name  = "SYNC_TOKENSERVER__RUN_MIGRATIONS"
            value = "true"
          }
          env {
            name  = "SYNC_TOKENSERVER__NODE_TYPE"
            value = "postgres"
          }
          env {
            name  = "SYNC_TOKENSERVER__FXA_EMAIL_DOMAIN"
            value = "api.accounts.firefox.com"
          }
          env {
            name  = "SYNC_TOKENSERVER__FXA_OAUTH_SERVER_URL"
            value = "https://oauth.accounts.firefox.com"
          }
          env {
            name  = "SYNC_TOKENSERVER__INIT_NODE_URL"
            value = "https://${var.config.hostname}.${var.config.domain}"
          }
          env {
            name  = "SYNC_TOKENSERVER__INIT_NODE_CAPACITY"
            value = "1"
          }
          env {
            name  = "SYNC_HUMAN_LOGS"
            value = "false"
          }
          env {
            name  = "RUST_LOG"
            value = "info"
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
          liveness_probe {
            http_get {
              path = "/__heartbeat__"
              port = var.config.port
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }
          readiness_probe {
            http_get {
              path = "/__heartbeat__"
              port = var.config.port
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_manifest.postgres,
    kubernetes_secret_v1.this
  ]
}