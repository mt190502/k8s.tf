## ============================================================================================= ##
#  modules/manifests/core/descheduler/helm.tf                                                     #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "descheduler"
  repository      = "https://kubernetes-sigs.github.io/descheduler/"
  chart           = "descheduler"
  version         = "0.36.0"
  namespace       = data.kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  set = [
    {
      name  = "deschedulerPolicyAPIVersion"
      value = "descheduler/v1alpha2"
    },
    {
      name  = "deschedulingInterval"
      value = var.config.descheduling_interval
    },
    {
      name  = "kind"
      value = "Deployment"
    },
    {
      name  = "leaderElection.enabled"
      value = "true"
    },
    {
      name  = "replicas"
      value = var.config.replicas
    },
    {
      name  = "serviceMonitor.enabled"
      value = "true"
    }
  ]
  values = [yamlencode({
    deschedulerPolicy = {
      profiles = [
        {
          name = "default"
          pluginConfig = [
            {
              name = "DefaultEvictor"
              args = {
                podProtections = {
                  defaultDisabled = [
                    "PodsWithLocalStorage",
                  ]
                  extraEnabled = [
                    "PodsWithPVC",
                  ]
                }
              }
            },
            {
              name = "LowNodeUtilization"
              args = {
                thresholds = {
                  cpu    = 20
                  memory = 20
                  pods   = 20
                }
                targetThresholds = {
                  cpu    = 70
                  memory = 70
                  pods   = 35
                }
                numberOfNodes = 1
                evictableNamespaces = {
                  exclude = [
                    "kube-system",
                    "cert-manager",
                    "longhorn-system",
                    "traefik-system",
                    "cnpg-system",
                  ]
                }
              }
            },
            {
              name = "RemoveDuplicates"
              args = {
                excludeOwnerKinds = [
                  "StatefulSet",
                ]
              }
            },
          ]
          plugins = {
            balance = {
              enabled = [
                "LowNodeUtilization",
                "RemoveDuplicates",
              ]
            }
          }
        },
      ]
    }
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
                  "app.kubernetes.io/name" = "descheduler"
                }
              }
              topologyKey = "kubernetes.io/hostname"
            }
          }
        ]
      }
    }
  })]
  depends_on = [data.kubernetes_namespace_v1.this]
}
