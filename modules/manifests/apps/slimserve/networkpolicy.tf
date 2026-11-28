## ============================================================================================= ##
#  modules/manifests/apps/slimserve/networkpolicy.tf                                              #
#                                                                                                 #
#  NetworkPolicy for clustered slimserve - HTTP port open to all sources, the Erlang              #
#  cluster port only between the app's own pods (mirrors the upstream Helm chart).                #
## ============================================================================================= ##
resource "kubernetes_manifest" "networkpolicy" {
  count = local.clustered ? 1 : 0
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = var.config.name
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      podSelector = {
        matchLabels = {
          "app.kubernetes.io/name" = var.config.name
        }
      }
      policyTypes = ["Ingress"]
      ingress = [
        {
          ports = [
            {
              port     = "http"
              protocol = "TCP"
            }
          ]
        },
        {
          from = [
            {
              podSelector = {
                matchLabels = {
                  "app.kubernetes.io/name" = var.config.name
                }
              }
            }
          ]
          ports = [
            {
              port     = "dist"
              protocol = "TCP"
            }
          ]
        }
      ]
    }
  }
  depends_on = [kubernetes_namespace_v1.this]
}
