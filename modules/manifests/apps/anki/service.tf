## ============================================================================================= ##
#  modules/manifests/apps/anki/service.tf                                                         #
#                                                                                                 #
#  ClusterIP Service for the application - exposes pods for internal cluster traffic.             #
#  Used as HTTPRoute backend for Gateway API ingress.                                             #
## ============================================================================================= ##
locals {
  traefik_service_enabled = var.enabled && var.config.port != null && try(var.config.replicas, 1) > 1
  traefik_service_name    = "${var.config.name}-sticky"
  traefik_service_manifest = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "TraefikService"
    metadata = {
      name      = local.traefik_service_name
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      weighted = {
        services = [
          {
            name   = kubernetes_service_v1.this[0].metadata[0].name
            port   = var.config.port
            kind   = "Service"
            weight = 1
            sticky = {
              cookie = {
                name     = local.traefik_service_name
                secure   = true
                httpOnly = true
                path     = "/"
              }
            }
          }
        ]
      }
    }
  })
}

resource "null_resource" "traefik_service" {
  count = local.traefik_service_enabled ? 1 : 0
  triggers = {
    manifest_sha = sha256(local.traefik_service_manifest)
    name         = local.traefik_service_name
    namespace    = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  provisioner "local-exec" {
    command = "kubectl apply -f - <<EOF\n${local.traefik_service_manifest}EOF"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete traefikservice ${self.triggers.name} -n ${self.triggers.namespace} --ignore-not-found=true"
  }
  depends_on = [kubernetes_service_v1.this]
}

resource "kubernetes_service_v1" "this" {
  count = (var.enabled && var.config.port != null) ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = var.config.name
    }
    port {
      port        = var.config.port
      target_port = var.config.port
    }
    type = "ClusterIP"
  }
  depends_on = [kubernetes_namespace_v1.this]
}