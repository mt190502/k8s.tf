## ============================================================================================= ##
#  modules/manifests/apps/silverbullet/service.tf                                                 #
#                                                                                                 #
#  ClusterIP Service for the application - used as HTTPRoute backend.                             #
## ============================================================================================= ##
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
    ip_family_policy = "PreferDualStack"
    ip_families      = ["IPv4", "IPv6"]
    type             = "ClusterIP"
  }
  depends_on = [kubernetes_namespace_v1.this]
}

# MCP sidecar endpoint. PreferDualStack with explicit families: the sidecar
# binds one dual-stack socket (IPv6 + IPv4-mapped), so both endpoint families
# serve. Reachable over the tailnet (subnet router) and - with mcp.public -
# through the public /mcp Gateway route behind the sidecar bearer token.
resource "kubernetes_service_v1" "mcp" {
  count = (var.enabled && var.config.mcp.enabled) ? 1 : 0
  metadata {
    name      = "${var.config.name}-mcp"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = var.config.name
    }
    port {
      name        = "mcp-http"
      port        = 8765
      target_port = 8765
    }
    ip_family_policy = "PreferDualStack"
    type             = "ClusterIP"
  }
  depends_on = [kubernetes_namespace_v1.this]
}
