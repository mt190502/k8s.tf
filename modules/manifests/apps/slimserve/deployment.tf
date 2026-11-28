## ============================================================================================= ##
#  modules/manifests/apps/slimserve/deployment.tf                                                 #
## ============================================================================================= ##
locals {
  clustered = var.enabled && coalesce(var.config.replicas, 1) > 1
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
    replicas = var.config.replicas
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "1"
        max_unavailable = "1"
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
        termination_grace_period_seconds = 30
        security_context {
          run_as_non_root = true
          run_as_user     = 1001
          run_as_group    = 1001
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }
        affinity {
          pod_anti_affinity {
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
        container {
          name  = var.config.name
          image = "ghcr.io/xeome/slimserve:1.1.0"
          port {
            name           = "http"
            container_port = var.config.port
          }
          dynamic "port" {
            for_each = local.clustered ? [1] : []
            content {
              name           = "dist"
              container_port = 4370
            }
          }
          env {
            name  = "PHX_HOST"
            value = "${var.config.hostname}.${var.config.domain}"
          }
          env {
            name  = "SLIMSERVE_HTTPS"
            value = "true"
          }
          env {
            name  = "SLIMSERVE_STORAGE"
            value = "s3"
          }
          env {
            name  = "SLIMSERVE_S3_BUCKET"
            value = var.config.bucket_name
          }
          env {
            name  = "AWS_ENDPOINT_URL_S3"
            value = var.config.s3_endpoint
          }
          env {
            name  = "AWS_REGION"
            value = var.config.s3_region
          }
          env {
            name  = "SLIMSERVE_DOWNLOAD_CACHE_MB"
            value = "1024"
          }
          env {
            name  = "SLIMSERVE_DOWNLOAD_CACHE_DIR"
            value = "/cache"
          }
          env {
            name  = "SLIMSERVE_CACHE_DIR"
            value = "/tmp/slimserve-thumbs"
          }
          env {
            name  = "ERL_CRASH_DUMP"
            value = "/tmp/erl_crash.dump"
          }
          env {
            name = "AWS_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.s3_credentials[0].metadata[0].name
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          }
          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.s3_credentials[0].metadata[0].name
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          }
          dynamic "env" {
            for_each = local.clustered ? [1] : []
            content {
              name = "POD_IP"
              value_from {
                field_ref {
                  field_path = "status.podIP"
                }
              }
            }
          }
          dynamic "env" {
            for_each = local.clustered ? [1] : []
            content {
              name  = "RELEASE_DISTRIBUTION"
              value = "name"
            }
          }
          dynamic "env" {
            for_each = local.clustered ? [1] : []
            content {
              name  = "RELEASE_NODE"
              value = "${var.config.name}@$(POD_IP)"
            }
          }
          dynamic "env" {
            for_each = local.clustered ? [1] : []
            content {
              name  = "DNS_CLUSTER_QUERY"
              value = "${var.config.name}-nodes.${kubernetes_namespace_v1.this[0].metadata[0].name}.svc.cluster.local"
            }
          }
          dynamic "env" {
            for_each = local.clustered ? [1] : []
            content {
              name = "RELEASE_COOKIE"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.s3_credentials[0].metadata[0].name
                  key  = "RELEASE_COOKIE"
                }
              }
            }
          }
          dynamic "env" {
            for_each = local.clustered ? [1] : []
            content {
              name = "SECRET_KEY_BASE"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.s3_credentials[0].metadata[0].name
                  key  = "SECRET_KEY_BASE"
                }
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
          startup_probe {
            http_get {
              path = "/.app/healthz"
              port = "http"
            }
            period_seconds    = 2
            failure_threshold = 30
          }
          liveness_probe {
            http_get {
              path = "/.app/healthz"
              port = "http"
            }
          }
          readiness_probe {
            http_get {
              path = "/.app/readyz"
              port = "http"
            }
          }
          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
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
            name       = "tmp"
            mount_path = "/tmp"
          }
          volume_mount {
            name       = "download-cache"
            mount_path = "/cache"
          }
        }
        volume {
          name = "tmp"
          empty_dir {}
        }
        volume {
          name = "download-cache"
          empty_dir {
            size_limit = "1024Mi"
            medium     = "Memory"
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.s3_credentials,
  ]
}
