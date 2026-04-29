## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/helm.tf                                           #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  version         = "84.4.0"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  wait            = false
  skip_crds       = true
  upgrade_install = true
  values = [yamlencode({
    crds = {
      enabled = false
    }
    grafana = {
      persistence = {
        enabled     = true
        accessModes = ["ReadWriteMany"]
        size        = var.config.storage_size
      }
      route = {
        main = {
          enabled    = true
          apiVersion = "gateway.networking.k8s.io/v1"
          kind       = "HTTPRoute"
          hostnames  = ["${var.config.hostname}.${var.config.domain}"]
          parentRefs = [
            {
              name      = var.config.gateway_name
              namespace = var.config.gateway_namespace
            }
          ]
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          filters = var.config.basic_auth && var.config.preferred_gateway == "traefik" ? [
            {
              type = "ExtensionRef"
              extensionRef = {
                group = "traefik.io"
                kind  = "Middleware"
                name  = "${var.config.name}-basic-auth"
              }
            }
          ] : []
        }
      }
    }
  })]
  depends_on = [kubernetes_namespace_v1.this]
}
