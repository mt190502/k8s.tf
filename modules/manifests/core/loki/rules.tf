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
              (
                sum by (namespace, pod, container) (
                  count_over_time(
                    {namespace=~".+"}
                    |~ "(?i)(error|fatal|panic)"
                    !~ "query_hash="
                    !~ "(?i)timestamp too old"
                    | json
                    | level =~ "(?i)error|fatal|panic"
                    [5m]
                  )
                )
                or
                sum by (namespace, pod, container) (
                  count_over_time(
                    {namespace=~".+"}
                    |~ "(?i)(error|fatal|panic)"
                    !~ "query_hash="
                    !~ "(?i)timestamp too old"
                    | logfmt
                    | level =~ "(?i)error|fatal|panic"
                    [5m]
                  )
                )
                or
                sum by (namespace, pod, container) (
                  count_over_time(
                    {namespace=~".+"}
                    |~ "^[EF][0-9]{4}\\s+[0-9]{2}:[0-9]{2}:[0-9]{2}"
                    !~ "(?i)(Handler timeout|context canceled|Post-timeout activity|Unhandled Error|write a (JSON|fallback JSON) response|apiserver received an error)"
                    [5m]
                  )
                )
                or
                sum by (namespace, pod, container) (
                  count_over_time(
                    {namespace=~".+"}
                    |~ "(?i)(\\berror\\b|\\bfatal\\b|\\bpanic\\b)"
                    !~ "^[EFIW][0-9]{4}\\s+[0-9]{2}:[0-9]{2}:[0-9]{2}"
                    !~ "query_hash="
                    !~ "(?i)timestamp too old"
                    | json
                    | __error__ = "JSONParserErr"
                    [5m]
                  )
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
