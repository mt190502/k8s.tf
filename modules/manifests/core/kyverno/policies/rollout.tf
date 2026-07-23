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
          preconditions = {
            all = [
              {
                key      = "{{ request.object.spec.template.spec.volumes[?persistentVolumeClaim] | length(@) }}"
                operator = "GreaterThan"
                value    = 0
              }
            ]
          }
          mutate = {
            patchStrategicMerge = {
              spec = {
                minReadySeconds         = 600
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
                        preferredDuringSchedulingIgnoredDuringExecution = [
                          {
                            weight = 100
                            podAffinityTerm = {
                              labelSelector = {
                                matchExpressions = [
                                  {
                                    key      = "app.kubernetes.io/name"
                                    operator = "Exists"
                                  }
                                ]
                              }
                              matchLabelKeys = ["app.kubernetes.io/name"]
                              topologyKey    = "kubernetes.io/hostname"
                            }
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
