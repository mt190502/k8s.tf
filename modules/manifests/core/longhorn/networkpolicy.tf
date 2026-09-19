## ============================================================================================= ##
#  modules/manifests/core/longhorn/networkpolicy.tf                                               #
## ============================================================================================= ##
resource "kubernetes_network_policy_v1" "allow_prometheus_metrics" {
  metadata {
    name      = "allow-prometheus-metrics"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = {
        app = "longhorn-manager"
      }
    }
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "monitoring"
          }
        }
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "prometheus"
          }
        }
      }
      ports {
        port     = "9500"
        protocol = "TCP"
      }
    }
    policy_types = ["Ingress"]
  }

  depends_on = [helm_release.this]
}
