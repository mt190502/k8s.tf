## ============================================================================================= ##
#  modules/manifests/apps/picoshare/deployment.tf                                                 #
#                                                                                                 #
#  Deployment for PicoShare - single replica file sharing server.                                 #
#  All shared content lives in the SQLite database on a ReadWriteOnce volume, so the rollout       #
#  strategy is Recreate: two pods must never write the same database.                              #
## ============================================================================================= ##
resource "kubernetes_deployment_v1" "this" {
  count = (var.enabled && var.config.port != null) ? 1 : 0
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
      type = "Recreate"
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
        annotations = {
          "checksum/config" = filesha256("${path.module}/deployment.tf")
        }
      }
      spec {
        security_context {
          fs_group        = 1000
          run_as_group    = 1000
          run_as_non_root = true
          run_as_user     = 1000
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        init_container {
          name  = "${var.config.name}-init"
          image = "mtlynch/picoshare:v1.5.4"
          command = [
            "sh",
            "-c",
            <<-EOT
              chown 1000:1000 /data
              chmod 0750 /data
            EOT
          ]
          security_context {
            allow_privilege_escalation = false
            run_as_user                = 0
            capabilities {
              drop = ["ALL"]
              add  = ["CHOWN", "FOWNER"]
            }
          }
          volume_mount {
            name       = "${var.config.name}-data"
            mount_path = "/data"
          }
        }

        container {
          name  = var.config.name
          image = "mtlynch/picoshare:v1.5.4"
          port {
            container_port = var.config.port
          }
          env {
            name  = "PORT"
            value = tostring(var.config.port)
          }
          env {
            name  = "PS_BEHIND_PROXY"
            value = "true"
          }
          env {
            name = "PS_SHARED_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.this[0].metadata[0].name
                key  = "shared_secret"
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
                cpu    = "250m"
                memory = "512Mi"
              } : {})
              requests = (var.config.resources.requests != null || var.config.resources.requests != {}) ? var.config.resources.requests : ((var.config.resources.limits == null || var.config.resources.limits == {}) ? {
                cpu    = "125m"
                memory = "256Mi"
              } : {})
            }
          }
          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }
          volume_mount {
            name       = "${var.config.name}-data"
            mount_path = "/data"
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
    kubernetes_secret_v1.this,
    kubernetes_persistent_volume_claim_v1.this,
  ]
}
