## ============================================================================================= ##
#  modules/manifests/apps/gotify/deployment.tf                                                    #
#                                                                                                 #
#  Deployment for stateless applications - manages replica pods with rolling updates.             #
#  Uses environment variables from config and secrets from Kubernetes Secret.                     #
## ============================================================================================= ##
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
          image = "gotify/server:2.9.1"
          dynamic "port" {
            for_each = var.config.port != null ? [var.config.port] : []
            content {
              container_port = port.value
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
    kubernetes_secret_v1.this
  ]
}

#~ bridge deployment generator
resource "kubernetes_deployment_v1" "bridge" {
  for_each = toset(nonsensitive(keys(var.secrets.bridges)))
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
            value = "5"
          }
          env {
            name  = "EXTENDED_DETAILS"
            value = "true"
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