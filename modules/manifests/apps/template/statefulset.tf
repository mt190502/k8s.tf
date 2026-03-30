## ============================================================================================= ##
#  modules/manifests/apps/template/statefulset.tf                                                 #
#                                                                                                 #
#  StatefulSet for stateful applications - provides stable network identity and persistent        #
#  storage. Each pod gets a stable hostname (pod-0, pod-1, etc.).                                 #
## ============================================================================================= ##
resource "kubernetes_stateful_set_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name" = var.config.name
    }
  }
  spec {
    service_name = "${var.config.name}-headless"
    replicas     = var.config.replicas
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
          dynamic "volume_mount" {
            for_each = var.config.storage_size != null ? [1] : []
            content {
              name       = "data"
              mount_path = "/data"
            }
          }
        }
      }
    }
    dynamic "volume_claim_template" {
      for_each = var.config.storage_size != null ? [1] : []
      content {
        metadata {
          name = "data"
        }
        spec {
          access_modes = ["ReadWriteOnce"]
          resources {
            requests = {
              storage = var.config.storage_size == null ? "1Gi" : var.config.storage_size
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.this
  ]
}