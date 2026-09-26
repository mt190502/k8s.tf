## ============================================================================================= ##
#  modules/manifests/core/reflector/helm.tf                                                       #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "reflector"
  repository      = "https://emberstack.github.io/helm-charts"
  chart           = "reflector"
  version         = "10.0.65"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  set = [
    { name = "cron.schedule", value = "*/15 * * * *", },
    { name = "resources.limits.memory", value = "736Mi", },
    { name = "resources.requests.cpu", value = "25m", },
    { name = "resources.requests.memory", value = "528Mi", },
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
                  "app.kubernetes.io/name" = "reflector"
                }
              }
              topologyKey = "kubernetes.io/hostname"
            }
          }
        ]
      }
    }
  })]
  depends_on = [kubernetes_namespace_v1.this]
}
