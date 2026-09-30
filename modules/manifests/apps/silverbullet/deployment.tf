## ============================================================================================= ##
#  modules/manifests/apps/silverbullet/deployment.tf                                              #
#                                                                                                 #
#  SilverBullet is a native web application for Markdown folders: no desktop streaming.           #
#  It is intentionally lightweight compared to a streamed Electron desktop.                       #
#  Gateway BasicAuth remains the public access control; SilverBullet auth (SB_USER) is optional.  #
## ============================================================================================= ##
resource "kubernetes_config_map_v1" "mcp_server" {
  count = (var.enabled && var.config.mcp.enabled) ? 1 : 0
  metadata {
    name      = "${var.config.name}-mcp"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    "mcp_server.py" = file("${path.module}/mcp_server.py")
  }
}

resource "kubernetes_secret_v1" "mcp" {
  count = (var.enabled && var.config.mcp.enabled) ? 1 : 0
  metadata {
    name      = "${var.config.name}-mcp"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  type = "Opaque"
  data = {
    token = try(var.secrets.mcp["token"], "")
  }
  lifecycle {
    precondition {
      condition     = !var.config.mcp.public || can(regex("^[A-Za-z0-9_-]{32,256}$", try(var.secrets.mcp["token"], "")))
      error_message = "Public MCP exposure requires a 32..256 character URL-safe ASCII bearer token in manifests.apps.silverbullet.mcp.token."
    }
  }
}

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
        annotations = var.config.mcp.enabled ? {
          "checksum/mcp-server" = filesha256("${path.module}/mcp_server.py")
        } : {}
      }
      spec {
        init_container {
          name  = "${var.config.name}-init"
          image = "busybox:1.36"
          command = [
            "sh",
            "-c",
            <<-EOT
            mkdir -p /vault/silverbullet /vault/mcp
            chmod -R a+rwX /vault/silverbullet /vault/mcp
            EOT
          ]
          volume_mount {
            name       = var.config.name
            mount_path = "/vault"
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
          env {
            name  = "SB_SPACE_IGNORE"
            value = "Library/*"
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
            sub_path   = "silverbullet"
          }
          volume_mount {
            name       = "shm"
            mount_path = "/dev/shm"
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
        dynamic "container" {
          for_each = var.config.mcp.enabled ? [1] : []
          iterator = bridge
          content {
            name              = "silverbullet-mcp"
            image             = "ghcr.io/astral-sh/uv:python3.12-bookworm-slim"
            image_pull_policy = "IfNotPresent"
            command           = ["uv", "run", "--script", "/app/mcp_server.py"]
            port {
              name           = "mcp-http"
              container_port = 8765
            }
            env {
              name  = "SILVERBULLET_URL"
              value = "http://${var.config.name}.${kubernetes_namespace_v1.this[0].metadata[0].name}.svc.cluster.local:${var.config.port}"
            }
            env {
              name  = "SILVERBULLET_MCP_PORT"
              value = "8765"
            }
            env {
              name  = "SILVERBULLET_MCP_INSTRUCTIONS"
              value = var.config.mcp.instructions
            }
            env {
              name  = "SILVERBULLET_MCP_PUBLIC_HOST"
              value = "${var.config.name}-mcp.${kubernetes_namespace_v1.this[0].metadata[0].name}.svc.cluster.local"
            }
            env {
              name  = "SILVERBULLET_MCP_PUBLIC_HOSTS"
              value = "${var.config.hostname}.${var.config.domain}"
            }
            env {
              name  = "SILVERBULLET_MCP_INTERNAL_HOSTS"
              value = "${var.config.name}-mcp.${kubernetes_namespace_v1.this[0].metadata[0].name}.svc.cluster.local"
            }
            env {
              name  = "UV_CACHE_DIR"
              value = "/scratch/uv-cache"
            }
            env {
              name  = "UV_PROJECT_ENVIRONMENT"
              value = "/scratch/venv"
            }
            env {
              name  = "UV_PYTHON_DOWNLOADS"
              value = "never"
            }
            env {
              name = "SILVERBULLET_MCP_TOKEN"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.mcp[0].metadata[0].name
                  key  = "token"
                }
              }
            }
            dynamic "resources" {
              for_each = var.config.mcp.resources != null ? [1] : []
              content {
                limits   = var.config.mcp.resources.limits
                requests = var.config.mcp.resources.requests
              }
            }
            readiness_probe {
              http_get {
                path = "/healthz"
                port = 8765
              }
              initial_delay_seconds = 3
              period_seconds        = 10
              timeout_seconds       = 3
            }
            liveness_probe {
              http_get {
                path = "/healthz"
                port = 8765
              }
              initial_delay_seconds = 15
              period_seconds        = 30
              timeout_seconds       = 3
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
              name       = "mcp-server"
              mount_path = "/app/mcp_server.py"
              sub_path   = "mcp_server.py"
              read_only  = true
            }
            volume_mount {
              name       = "sidecar-tmp"
              mount_path = "/tmp"
            }
            volume_mount {
              name       = var.config.name
              mount_path = "/scratch"
              sub_path   = "mcp"
            }
          }
        }
        volume {
          name = var.config.name
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.this[0].metadata[0].name
          }
        }
        volume {
          name = "shm"
          empty_dir {
            medium     = "Memory"
            size_limit = "1Gi"
          }
        }
        volume {
          name = "sidecar-tmp"
          empty_dir {
            size_limit = "256Mi"
          }
        }
        dynamic "volume" {
          for_each = var.config.mcp.enabled ? [1] : []
          content {
            name = "mcp-server"
            config_map {
              name = kubernetes_config_map_v1.mcp_server[0].metadata[0].name
            }
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.this, kubernetes_persistent_volume_claim_v1.this]
}
