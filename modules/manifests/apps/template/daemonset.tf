## ============================================================================================= ##
#  modules/manifests/apps/apps/template/daemonset.tf                                              #
#                                                                                                 #
#  DaemonSet ensures a pod runs on every node (or selected nodes) - useful for system             #
#  agents, log collectors, monitoring daemons.                                                    #
## ============================================================================================= ##
resource "kubernetes_daemon_set_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
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
  depends_on = [kubernetes_namespace_v1.this]
}