## ============================================================================================= ##
#  modules/manifests/core/alloy/helm.tf                                                           #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "alloy"
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "alloy"
  version         = "1.8.1"
  namespace       = var.config.kps_namespace
  upgrade_install = true
  values = [yamlencode({
    alloy = {
      configMap = {
        content = <<-EOT
          logging {
            level = "info"
          }

          loki.write "default" {
            endpoint {
              url = "http://loki-gateway/loki/api/v1/push"
            }
          }

          discovery.kubernetes "pods" {
            role = "pod"
          }

          discovery.relabel "pod_logs" {
            targets = discovery.kubernetes.pods.targets

            rule {
              source_labels = ["__meta_kubernetes_namespace"]
              action = "replace"
              target_label = "namespace"
            }

            rule {
              source_labels = ["__meta_kubernetes_pod_name"]
              action = "replace"
              target_label = "pod"
            }

            rule {
              source_labels = ["__meta_kubernetes_pod_container_name"]
              action = "replace"
              target_label = "container"
            }

            rule {
              source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
              action = "replace"
              target_label = "app"
            }

            rule {
              source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_pod_container_name"]
              action = "replace"
              target_label = "job"
              separator = "/"
              replacement = "$1"
            }

            rule {
              source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
              action = "replace"
              target_label = "__path__"
              separator = "/"
              replacement = "/var/log/pods/*$1/*.log"
            }

            rule {
              source_labels = ["__meta_kubernetes_pod_container_id"]
              action = "replace"
              target_label = "container_runtime"
              regex = "^(\\S+):\\/\\/.+$"
              replacement = "$1"
            }
          }

          loki.source.kubernetes "pod_logs" {
            targets    = discovery.relabel.pod_logs.output
            forward_to = [loki.write.default.receiver]
          }
        EOT
      }
    }
    controller = {
      tolerations = [
        {
          key      = "node-role.kubernetes.io/control-plane",
          operator = "Exists",
          effect   = "NoSchedule"
        }
      ]
      affinity = {
        podAntiAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchLabels = {
                    "app.kubernetes.io/name" : "alloy"
                  }
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }
          ]
        }
      }
    }
  })]
}
