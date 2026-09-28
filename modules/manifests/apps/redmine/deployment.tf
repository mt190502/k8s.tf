## ============================================================================================= ##
#  modules/manifests/apps/redmine/deployment.tf                                                   #
#                                                                                                 #
#  Deployment for stateless applications - manages replica pods with rolling updates.             #
#  Uses environment variables from config and secrets from Kubernetes Secret.                     #
## ============================================================================================= ##
resource "kubernetes_config_map_v1" "task_sync_adapter_app" {
  count = (var.enabled && var.config.task_sync_adapter.enabled) ? 1 : 0
  metadata {
    name      = "${var.config.task_sync_adapter.name}-app"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    "task_sync_adapter.py" = file("${path.module}/task_sync_adapter.py")
  }
}

resource "kubernetes_secret_v1" "task_sync_adapter_app" {
  count = (var.enabled && var.config.task_sync_adapter.enabled) ? 1 : 0
  metadata {
    name      = "${var.config.task_sync_adapter.name}-app"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  type = "Opaque"
  data = {
    redmine_api_key   = try(var.secrets.task_sync_adapter["redmine_api_key"], "")
    radicale_username = try(var.secrets.task_sync_adapter["radicale_username"], "")
    radicale_password = try(var.secrets.task_sync_adapter["radicale_password"], "")
  }
}

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
    replicas                  = var.config.replicas
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
        annotations = var.config.task_sync_adapter.enabled ? {
          "checksum/task-sync-adapter" = filesha256("${path.module}/task_sync_adapter.py")
        } : {}
      }
      spec {
        affinity {
          pod_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  "app.kubernetes.io/name" = var.config.name
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }

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
            %{if var.config.task_sync_adapter.enabled~}
            mkdir -p /data/gateway-state
            %{endif~}
            EOT
          ]
          dynamic "volume_mount" {
            for_each = var.config.task_sync_adapter.enabled ? [1] : []
            content {
              name       = "${var.config.name}-data"
              mount_path = "/data"
            }
          }
        }
        container {
          name  = var.config.name
          image = "redmine:7.0.1"
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
        dynamic "container" {
          for_each = var.config.task_sync_adapter.enabled ? [var.config.task_sync_adapter] : []
          iterator = adapter
          content {
            name              = adapter.value.name
            image             = "python:3.13-alpine"
            image_pull_policy = "IfNotPresent"
            command           = ["python", "/app/task_sync_adapter.py"]
            env {
              name  = "REDMINE_URL"
              value = "http://127.0.0.1:${var.config.port}"
            }
            env {
              name  = "REDMINE_PROJECT"
              value = adapter.value.redmine_project
            }
            env {
              name  = "RADICALE_URL"
              value = "https://radicale.radicale.svc.cluster.local:5232"
            }
            env {
              name  = "RADICALE_TLS_SERVER_NAME"
              value = "dav.${var.config.domain}"
            }
            env {
              name  = "RADICALE_CALENDAR"
              value = adapter.value.radicale_calendar
            }
            env {
              name  = "SYNC_INTERVAL_SECONDS"
              value = tostring(adapter.value.sync_interval_seconds)
            }
            env {
              name  = "REDMINE_CLOSED_STATUS_ID"
              value = tostring(adapter.value.redmine_closed_status_id)
            }
            env {
              name  = "CALENDAR_DELETE_CLOSE"
              value = tostring(adapter.value.calendar_delete_close)
            }
            env {
              name  = "STATE_DB"
              value = "/data/state.sqlite3"
            }
            env {
              name = "REDMINE_API_KEY"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.task_sync_adapter_app[0].metadata[0].name
                  key  = "redmine_api_key"
                }
              }
            }
            env {
              name = "RADICALE_USERNAME"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.task_sync_adapter_app[0].metadata[0].name
                  key  = "radicale_username"
                }
              }
            }
            env {
              name = "RADICALE_PASSWORD"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.task_sync_adapter_app[0].metadata[0].name
                  key  = "radicale_password"
                }
              }
            }
            dynamic "resources" {
              for_each = adapter.value.resources != null ? [1] : []
              content {
                limits   = try(adapter.value.resources.limits, {})
                requests = try(adapter.value.resources.requests, {})
              }
            }
            volume_mount {
              name       = "gateway-app"
              mount_path = "/app/task_sync_adapter.py"
              sub_path   = "task_sync_adapter.py"
              read_only  = true
            }
            volume_mount {
              name       = "${var.config.name}-data"
              mount_path = "/data"
              sub_path   = "gateway-state"
            }
          }
        }
        dynamic "volume" {
          for_each = var.config.task_sync_adapter.enabled ? [1] : []
          content {
            name = "gateway-app"
            config_map {
              name = kubernetes_config_map_v1.task_sync_adapter_app[0].metadata[0].name
            }
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
    kubernetes_manifest.postgres,
    kubernetes_config_map_v1.task_sync_adapter_app,
    kubernetes_secret_v1.task_sync_adapter_app,
  ]
}
