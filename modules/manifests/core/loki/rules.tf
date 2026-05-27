## ============================================================================================= ##
#  modules/manifests/core/loki/rules.tf                                                           #
## ============================================================================================= ##
locals {
  loki_alert_rules = yamlencode({
    groups = [
      {
        name = "loki-rules"
        rules = [
          {
            alert = "LokiErrorLog"
            expr  = <<-EOT
              sum by (namespace, pod, container) (
                count_over_time(
                  {namespace=~".+"}
                  |~ "(?i)(error|fatal|panic)"
                  | json
                  | level =~ "(?i)error|fatal|panic" or __error__ != ""
                  [5m]
                )
              ) > 20
            EOT
            for   = "5m"
            labels = {
              severity = "warning"
            }
            annotations = {
              summary     = "Error log in {{ $labels.namespace }}/{{ $labels.pod }}"
              description = <<-EOT
                {{ $value | humanize }} error lines in the last 5 minutes
                on {{ $labels.pod }}/{{ $labels.container }} ({{ $labels.namespace }})
              EOT
            }
          }
        ]
      }
    ]
  })
}

resource "kubernetes_config_map_v1" "loki_rules" {
  metadata {
    name      = "loki-rules"
    namespace = var.config.kps_namespace
    labels = {
      "app.kubernetes.io/part-of" = "loki"
    }
  }

  data = {
    "rules.yaml" = local.loki_alert_rules
  }
}
