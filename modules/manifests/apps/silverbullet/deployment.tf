## ============================================================================================= ##
#  modules/manifests/apps/silverbullet/deployment.tf                                              #
#                                                                                                 #
#  SilverBullet is a native web application for Markdown folders: no desktop streaming.           #
#  It is intentionally lightweight compared to a streamed Electron desktop.                       #
#  Gateway BasicAuth remains the public access control; SilverBullet auth (SB_USER) is optional.  #
## ============================================================================================= ##
resource "kubernetes_deployment_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name" = var.config.name
    }
  }
  spec {
    replicas                  = 1
    min_ready_seconds         = 300
    progress_deadline_seconds = 1200
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "1%"
        max_unavailable = "0%"
      }
    }
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
          name    = "${var.config.name}-init"
          image   = "busybox:1.36"
          command = ["sh", "-c", "chmod -R a+rwX /space"]
          volume_mount {
            name       = var.config.name
            mount_path = "/space"
          }
        }
        container {
          name              = var.config.name
          image             = var.config.image
          image_pull_policy = "IfNotPresent"
          port {
            container_port = var.config.port
          }
          env {
            name  = "SB_HOSTNAME"
            value = "::"
          }
          args = ["--single"]
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
              limits   = (var.config.resources.limits != null && var.config.resources.limits != {}) ? var.config.resources.limits : { cpu = "200m", memory = "512Mi" }
              requests = (var.config.resources.requests != null && var.config.resources.requests != {}) ? var.config.resources.requests : { cpu = "25m", memory = "96Mi" }
            }
          }
          volume_mount {
            name       = var.config.name
            mount_path = "/space"
          }
          readiness_probe {
            http_get {
              path = "/"
              port = var.config.port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 3
          }
          liveness_probe {
            http_get {
              path = "/"
              port = var.config.port
            }
            initial_delay_seconds = 20
            period_seconds        = 30
            timeout_seconds       = 3
          }
        }
        volume {
          name = var.config.name
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.this[0].metadata[0].name
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.this, kubernetes_persistent_volume_claim_v1.this]
}
