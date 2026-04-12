## ============================================================================================= ##
#  modules/manifests/core/atlantis/kubeconfig.tf                                                  #
## ============================================================================================= ##
resource "kubernetes_config_map_v1" "kubeconfig" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-kubeconfig"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    config = yamlencode({
      apiVersion = "v1"
      kind       = "Config"
      clusters = [
        {
          name = "in-cluster"
          cluster = {
            server                     = "https://kubernetes.default.svc"
            "certificate-authority"    = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
            "insecure-skip-tls-verify" = false
          }
        }
      ]
      contexts = [
        {
          name = "atlantis"
          context = {
            cluster = "in-cluster"
            user    = "atlantis"
          }
        }
      ]
      current-context = "atlantis"
      users = [
        {
          name = "atlantis"
          user = {
            tokenFile = "/var/run/secrets/kubernetes.io/serviceaccount/token"
          }
        }
      ]
    })
  }

  depends_on = [kubernetes_namespace_v1.this]
}
