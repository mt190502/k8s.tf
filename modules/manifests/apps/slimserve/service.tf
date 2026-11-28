## =========================================================================================== ##
#  modules/manifests/apps/slimserve/service.tf                                                  #
## =========================================================================================== ##
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
    type             = "ClusterIP"
  }
  depends_on = [kubernetes_namespace_v1.this]
}

## --------------------------------------------------------------------------------------------- ##
#  Headless Service for the Erlang cluster - pod discovery on port 4370 only.                     #
#  Never exposed publicly; the HTTP Service stays unchanged.                                      #
## --------------------------------------------------------------------------------------------- ##
resource "kubernetes_service_v1" "nodes" {
  count = local.clustered ? 1 : 0
  metadata {
    name      = "${var.config.name}-nodes"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = var.config.name
    }
    port {
      name        = "dist"
      port        = 4370
      target_port = 4370
    }
    cluster_ip                  = "None"
    publish_not_ready_addresses = true
  }
  depends_on = [kubernetes_namespace_v1.this]
}
