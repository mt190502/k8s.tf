## ============================================================================================= ##
#  modules/manifests/core/cnpg/helm.tf                                                            #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "cloudnative-pg"
  repository      = "https://cloudnative-pg.github.io/charts"
  chart           = "cloudnative-pg"
  version         = "0.28.0"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  set = [
    {
      name  = "replicaCount"
      value = var.config.controlplane_count
    }
  ]
  values = [yamlencode({
    tolerations = [
      {
        key      = "node-role.kubernetes.io/control-plane",
        operator = "Exists",
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
                  "app.kubernetes.io/name" : "cloudnative-pg"
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
