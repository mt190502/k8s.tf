## ============================================================================================= ##
#  StatefulSet for HedgeDoc with persistent SQLite storage.                                       #
## ============================================================================================= ##
resource "kubernetes_stateful_set_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    labels    = { "app.kubernetes.io/name" = var.config.name }
  }
  spec {
    service_name = "${var.config.name}-headless"
    replicas     = 1
    selector { match_labels = { "app.kubernetes.io/name" = var.config.name } }
    template {
      metadata { labels = { "app.kubernetes.io/name" = var.config.name } }
      spec {
        init_container {
          name    = "hedgedoc-init"
          image   = "busybox:1.36"
          command = ["sh", "-c", "chmod -R a+rwX /data"]
          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
        }
        container {
          name  = var.config.name
          image = "quay.io/hedgedoc/hedgedoc:1.12.0"
          port { container_port = var.config.port }
          env {
            name = "CMD_SESSION_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.this[0].metadata[0].name
                key  = "session_secret"
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
          dynamic "resources" {
            for_each = var.config.resources != null ? [1] : []
            content {
              limits   = (var.config.resources.limits != null && var.config.resources.limits != {}) ? var.config.resources.limits : { cpu = "1", memory = "1Gi" }
              requests = (var.config.resources.requests != null && var.config.resources.requests != {}) ? var.config.resources.requests : { cpu = "250m", memory = "512Mi" }
            }
          }
          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
          volume_mount {
            name       = "data"
            mount_path = "/hedgedoc/public/uploads"
          }
        }
      }
    }
    volume_claim_template {
      metadata { name = "data" }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources { requests = { storage = var.config.storage_size } }
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.this]
}
