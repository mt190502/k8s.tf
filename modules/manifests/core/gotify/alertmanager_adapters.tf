## ============================================================================================= ##
# One Pod for Alertmanager's independent Discord and Gotify webhook receivers.                    #
# Separate containers/ports preserve each receiver's retry and Gotify priority behavior.          #
## ============================================================================================= ##
resource "kubernetes_config_map_v1" "discord_adapter" {
  count = local.discord_adapter_enabled ? 1 : 0
  metadata {
    name      = "alertmanager-discord-adapter"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    "server.py" = file("${path.module}/discord_adapter.py")
  }
}

resource "kubernetes_secret_v1" "discord_adapter" {
  count = local.discord_adapter_enabled ? 1 : 0
  metadata {
    name      = "alertmanager-discord-adapter"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    webhook_url = var.secrets.discord_webhook_url
  }
  type       = "Opaque"
  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_deployment_v1" "alertmanager_adapters" {
  count = local.alertmanager_adapters_enabled ? 1 : 0
  metadata {
    name      = "alertmanager-notification-adapters"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    labels    = local.alertmanager_adapters_labels
  }
  spec {
    replicas = 1
    selector {
      match_labels = local.alertmanager_adapters_labels
    }
    template {
      metadata {
        labels = local.alertmanager_adapters_labels
        annotations = {
          "checksum/discord-adapter-code" = filesha256("${path.module}/discord_adapter.py")
        }
      }
      spec {
        container {
          name              = "alertmanager-gotify-bridge"
          image             = "ghcr.io/druggeri/alertmanager_gotify_bridge:2.3.2"
          image_pull_policy = "IfNotPresent"
          port {
            name           = "gotify-normal"
            container_port = 8080
          }
          env {
            name  = "PORT"
            value = "8080"
          }
          env {
            name  = "GOTIFY_ENDPOINT"
            value = "http://${var.config.name}.${kubernetes_namespace_v1.this[0].metadata[0].name}.svc.cluster.local/message"
          }
          env {
            name = "GOTIFY_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.bridge["alertmanager"].metadata[0].name
                key  = "gotify_token"
              }
            }
          }
          env {
            name  = "DEFAULT_PRIORITY"
            value = "5"
          }
          env {
            name  = "EXTENDED_DETAILS"
            value = "true"
          }
          liveness_probe {
            http_get {
              path = "/metrics"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
          readiness_probe {
            http_get {
              path = "/metrics"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
          resources {
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
        }
        container {
          name              = "alertmanager-info-gotify-bridge"
          image             = "ghcr.io/druggeri/alertmanager_gotify_bridge:2.3.2"
          image_pull_policy = "IfNotPresent"
          port {
            name           = "gotify-info"
            container_port = 8081
          }
          env {
            name  = "PORT"
            value = "8081"
          }
          env {
            name  = "GOTIFY_ENDPOINT"
            value = "http://${var.config.name}.${kubernetes_namespace_v1.this[0].metadata[0].name}.svc.cluster.local/message"
          }
          env {
            name = "GOTIFY_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.bridge["alertmanager-info"].metadata[0].name
                key  = "gotify_token"
              }
            }
          }
          env {
            name  = "DEFAULT_PRIORITY"
            value = "0"
          }
          env {
            name  = "EXTENDED_DETAILS"
            value = "true"
          }
          liveness_probe {
            http_get {
              path = "/metrics"
              port = 8081
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
          readiness_probe {
            http_get {
              path = "/metrics"
              port = 8081
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
          resources {
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
        }
        dynamic "container" {
          for_each = local.discord_adapter_enabled ? [1] : []
          content {
            name              = "discord-adapter"
            image             = "python:3.12-alpine"
            image_pull_policy = "IfNotPresent"
            command           = ["python", "-B", "/app/server.py"]
            port {
              name           = "discord-http"
              container_port = 8082
            }
            env {
              name  = "PORT"
              value = "8082"
            }
            env {
              name = "DISCORD_WEBHOOK_URL"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.discord_adapter[0].metadata[0].name
                  key  = "webhook_url"
                }
              }
            }
            readiness_probe {
              http_get {
                path = "/healthz"
                port = 8082
              }
              initial_delay_seconds = 2
              period_seconds        = 10
            }
            liveness_probe {
              http_get {
                path = "/healthz"
                port = 8082
              }
              initial_delay_seconds = 5
              period_seconds        = 20
            }
            resources {
              limits = {
                cpu    = "200m"
                memory = "64Mi"
              }
              requests = {
                cpu    = "10m"
                memory = "32Mi"
              }
            }
            security_context {
              allow_privilege_escalation = false
              read_only_root_filesystem  = true
              run_as_non_root            = true
              run_as_user                = 10001
              capabilities {
                drop = ["ALL"]
              }
            }
            volume_mount {
              name       = "adapter-code"
              mount_path = "/app"
              read_only  = true
            }
          }
        }
        dynamic "volume" {
          for_each = local.discord_adapter_enabled ? [1] : []
          content {
            name = "adapter-code"
            config_map {
              name = kubernetes_config_map_v1.discord_adapter[0].metadata[0].name
            }
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_secret_v1.bridge,
    kubernetes_config_map_v1.discord_adapter,
    kubernetes_secret_v1.discord_adapter,
  ]
}

resource "kubernetes_service_v1" "discord_adapter" {
  count = local.discord_adapter_enabled ? 1 : 0
  metadata {
    name      = "alertmanager-discord-adapter"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  spec {
    selector = local.alertmanager_adapters_labels
    port {
      name        = "http"
      port        = 8080
      target_port = 8082
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_deployment_v1.alertmanager_adapters]
}
