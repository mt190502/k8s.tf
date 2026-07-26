resource "kubernetes_manifest" "persistent_volume_rollout" {
  manifest = {
    apiVersion = "kyverno.io/v1"
    kind       = "ClusterPolicy"
    metadata = {
      name = "persistent-volume-rollout"
    }
    spec = {
      admission  = true
      background = false
      rules = [
        {
          name = "set-safe-rollout-for-persistent-volumes"
          match = {
            any = [
              {
                resources = {
                  kinds      = ["Deployment"]
                  operations = ["CREATE", "UPDATE"]
                }
              }
            ]
          }
          exclude = {
            any = [
              {
                resources = {
                  namespaces = ["slimserve"]
                }
              }
            ]
          }
          preconditions = {
            all = [
              {
                key      = "{{ request.object.spec.template.metadata.labels.\"app.kubernetes.io/name\" || '' }}"
                operator = "NotEquals"
                value    = ""
              },
              {
                key      = "{{ (request.object.spec.template.spec.volumes || `[]`) | [?persistentVolumeClaim] | length(@) }}"
                operator = "GreaterThan"
                value    = 0
              }
            ]
          }
          mutate = {
            patchStrategicMerge = {
              spec = {
                minReadySeconds         = 300
                progressDeadlineSeconds = 1200
                strategy = {
                  type = "RollingUpdate"
                  rollingUpdate = {
                    maxSurge       = "1%"
                    maxUnavailable = "0%"
                  }
                }
                template = {
                  spec = {
                    affinity = {
                      podAffinity = {
                        preferredDuringSchedulingIgnoredDuringExecution = []
                        requiredDuringSchedulingIgnoredDuringExecution = [
                          {
                            labelSelector = {
                              matchLabels = {
                                "app.kubernetes.io/name" = "{{ request.object.spec.template.metadata.labels.\"app.kubernetes.io/name\" }}"
                              }
                            }
                            topologyKey = "kubernetes.io/hostname"
                          }
                        ]
                      }
                    }
                  }
                }
              }
            }
          }
        }
      ]
    }
  }
}
