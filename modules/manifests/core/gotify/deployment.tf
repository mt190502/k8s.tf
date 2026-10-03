## ============================================================================================= ##
#  modules/manifests/core/gotify/deployment.tf                                                    #
#                                                                                                 #
#  Deployment for stateless applications - manages replica pods with rolling updates.             #
#  Uses environment variables from config and secrets from Kubernetes Secret.                     #
## ============================================================================================= ##
locals {
  bridge_names = try(nonsensitive(keys(var.secrets.bridges)), [])
  bridge_keys  = toset(concat(local.bridge_names, contains(local.bridge_names, "alertmanager") ? ["alertmanager-info"] : []))

  alertmanager_bridge_keys      = toset(["alertmanager", "alertmanager-info"])
  alertmanager_adapters_labels  = { "app.kubernetes.io/name" = "alertmanager-notification-adapters" }
  alertmanager_adapters_enabled = var.enabled && contains(local.bridge_keys, "alertmanager")
  discord_adapter_enabled       = local.alertmanager_adapters_enabled && nonsensitive(try(trimspace(var.secrets.discord_webhook_url), "")) != ""
  individual_bridge_keys        = setsubtract(local.bridge_keys, local.alertmanager_bridge_keys)
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
            until nc -zv ${var.config.name}-postgres-rw.${kubernetes_namespace_v1.this[0].metadata[0].name}.svc.cluster.local 5432; do
              echo "Waiting for PostgreSQL to be ready..."
              sleep 5
            done
            EOT
          ]
        }
        container {
          name  = var.config.name
          image = "gotify/server:3.1.1"
          dynamic "port" {
            for_each = var.config.port != null ? [var.config.port] : []
            content {
              container_port = port.value
            }
          }
          env {
            name  = "GOTIFY_DATABASE_DIALECT"
            value = "postgres"
          }
          env {
            name = "GOTIFY_DATABASE_CONNECTION"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgres[0].metadata[0].name
                key  = "connection"
              }
            }
          }
          env {
            name = "GOTIFY_DEFAULTUSER_PASS"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.this[0].metadata[0].name
                key  = "password"
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
              initial_delay_seconds = 60
              period_seconds        = 30
              timeout_seconds       = 5
              failure_threshold     = 3
            }
          }
          dynamic "readiness_probe" {
            for_each = var.config.port != null ? [1] : []
            content {
              http_get {
                path = "/health"
                port = var.config.port
              }
              initial_delay_seconds = 15
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
          volume_mount {
            name       = "${var.config.name}-data"
            mount_path = "/app/data"
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
    kubernetes_manifest.postgres
  ]
}

#~ bridge deployment generator
resource "kubernetes_deployment_v1" "bridge" {
  for_each = local.individual_bridge_keys
  metadata {
    name      = "${each.key}-${var.config.name}-bridge"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "${each.key}-${var.config.name}-bridge"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "${each.key}-${var.config.name}-bridge"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "${each.key}-${var.config.name}-bridge"
        }
      }
      spec {
        container {
          name  = "${each.key}-${var.config.name}-bridge"
          image = "ghcr.io/druggeri/alertmanager_gotify_bridge:2.3.2"
          port {
            container_port = 8080
          }
          env {
            name  = "GOTIFY_ENDPOINT"
            value = "http://${var.config.name}.${kubernetes_namespace_v1.this[0].metadata[0].name}.svc.cluster.local/message"
          }
          env {
            name = "GOTIFY_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.bridge[each.key].metadata[0].name
                key  = "gotify_token"
              }
            }
          }
          env {
            name  = "DEFAULT_PRIORITY"
            value = each.key == "alertmanager-info" ? "0" : "5"
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
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.this, kubernetes_secret_v1.bridge]
}
