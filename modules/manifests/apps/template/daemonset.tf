## ============================================================================================= ##
#  modules/manifests/apps/<<<template>>>/daemonset.tf                                             #
#                                                                                                 #
#  DaemonSet ensures a pod runs on every node (or selected nodes) - useful for system             #
#  agents, log collectors, monitoring daemons.                                                    #
## ============================================================================================= ##
resource "kubernetes_daemon_set_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name" = var.config.name
    }
  }
  spec {
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
        container {
          name  = var.config.name
          image = "<<<template>>>:latest"
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
          dynamic "liveness_probe" {
            for_each = var.config.port != null ? [1] : []
            content {
              tcp_socket {
                port = var.config.port
              }
              initial_delay_seconds = 30
              period_seconds        = 30
              timeout_seconds       = 5
              failure_threshold     = 3
            }
          }
          dynamic "readiness_probe" {
            for_each = var.config.port != null ? [1] : []
            content {
              tcp_socket {
                port = var.config.port
              }
              initial_delay_seconds = 10
              period_seconds        = 10
              timeout_seconds       = 5
              failure_threshold     = 3
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
  depends_on = [kubernetes_namespace_v1.this]
}