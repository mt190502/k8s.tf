## ============================================================================================= ##
#  modules/manifests/core/tailscale-operator/helm.tf                                              #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "tailscale-operator"
  repository      = "https://pkgs.tailscale.com/helmcharts"
  chart           = "tailscale-operator"
  version         = "1.102.3"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  set = [
    {
      name  = "operatorConfig.defaultTags"
      value = "tag:k8s-operator"
    },
    {
      name  = "proxyConfig.defaultTags"
      value = "tag:k8s-pods"
    }
  ]
  values = [yamlencode({
    tolerations = [
      {
        key      = "node-role.kubernetes.io/control-plane"
        operator = "Exists"
        effect   = "NoSchedule"
      }
    ]
    nodeSelector = {
      "node-role.kubernetes.io/control-plane" = ""
    }
    affinity = {
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            weight = 100
            podAffinityTerm = {
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/name" = "tailscale-operator"
                  topologyKey              = "kubernetes.io/hostname"
                }
              }
            }
          }
        ]
      }
    }
  })]
  depends_on = [
    kubernetes_secret_v1.operator_oauth,
    kubernetes_secret_v1.tailscale_auth
  ]
}
