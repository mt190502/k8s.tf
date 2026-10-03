resource "kubernetes_manifest" "persistent_volume_rollout" {
  manifest = {
    apiVersion = "policies.kyverno.io/v1"
    kind       = "MutatingPolicy"
    metadata = {
      name = "persistent-volume-rollout"
    }
    spec = {
      evaluation = {
        admission          = { enabled = true }
        background         = { enabled = false }
        useServerSideApply = true
      }
      matchConstraints = {
        namespaceSelector = {
          matchExpressions = [
            {
              key      = "kubernetes.io/metadata.name"
              operator = "NotIn"
              values   = ["slimserve", "anki"]
            }
          ]
        }
        resourceRules = [
          {
            apiGroups   = ["apps"]
            apiVersions = ["v1"]
            operations  = ["CREATE", "UPDATE"]
            resources   = ["deployments"]
            scope       = "Namespaced"
          }
        ]
      }
      matchConditions = [
        {
          name       = "has-app-name-label"
          expression = "has(object.spec.template.metadata.labels) && 'app.kubernetes.io/name' in object.spec.template.metadata.labels && object.spec.template.metadata.labels['app.kubernetes.io/name'] != ''"
        },
        {
          name       = "uses-persistent-volume-claim"
          expression = "object.spec.template.spec.?volumes.orValue([]).exists(v, has(v.persistentVolumeClaim))"
        }
      ]
      mutations = [
        {
          patchType = "ApplyConfiguration"
          applyConfiguration = {
            expression = <<-CEL
              Object{
                spec: Object.spec{
                  minReadySeconds: 300,
                  progressDeadlineSeconds: 1200,
                  strategy: Object.spec.strategy{
                    type: "RollingUpdate",
                    rollingUpdate: Object.spec.strategy.rollingUpdate{
                      maxSurge: "1%",
                      maxUnavailable: "0%"
                    }
                  },
                  template: Object.spec.template{
                    spec: Object.spec.template.spec{
                      affinity: Object.spec.template.spec.affinity{
                        podAffinity: Object.spec.template.spec.affinity.podAffinity{
                          preferredDuringSchedulingIgnoredDuringExecution: [],
                          requiredDuringSchedulingIgnoredDuringExecution: [
                            Object.spec.template.spec.affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution{
                              labelSelector: Object.spec.template.spec.affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution.labelSelector{
                                matchLabels: {
                                  "app.kubernetes.io/name": object.spec.template.metadata.labels["app.kubernetes.io/name"]
                                }
                              },
                              topologyKey: "kubernetes.io/hostname"
                            }
                          ]
                        }
                      }
                    }
                  }
                }
              }
            CEL
          }
        }
      ]
    }
  }
}
