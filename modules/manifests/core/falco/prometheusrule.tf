## ============================================================================================= ##
#  modules/manifests/core/falco/prometheusrule.tf                                                 #
## ============================================================================================= ##
resource "kubernetes_manifest" "prometheus_rule" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "falco-alerts"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
      labels = {
        "app.kubernetes.io/part-of" = helm_release.this.name
      }
    }
    spec = {
      groups = [
        {
          name = "falco.rules"
          rules = [
            {
              alert = "FalcoEventsDropped"
              expr  = "sum by (pod) (rate(falcosecurity_scap_n_drops_total[5m])) / sum by (pod) (rate(falcosecurity_scap_n_evts_total[5m])) > 0.01"
              "for" = "10m"
              labels = {
                severity  = "warning"
                component = "falco"
              }
              annotations = {
                summary     = "Falco is dropping kernel events"
                description = "Falco on {{ $labels.pod }} drops more than 1% of kernel events over the last 5 minutes; the runtime threat coverage is incomplete."
              }
            },
            {
              alert = "FalcoOutputsQueueDropped"
              expr  = "sum by (pod) (increase(falcosecurity_falco_outputs_queue_num_drops_total[15m])) > 0"
              "for" = "5m"
              labels = {
                severity  = "warning"
                component = "falco"
              }
              annotations = {
                summary     = "Falco output queue drops detected"
                description = "Falco on {{ $labels.pod }} dropped {{ $value }} outputs in the last 15 minutes; alerts (e.g. to falcosidekick) are being lost."
              }
            },
            {
              alert = "FalcoMetricsTargetDown"
              expr  = "up{namespace=\"falco\", job=\"falco-metrics\"} == 0"
              "for" = "10m"
              labels = {
                severity  = "critical"
                component = "falco"
              }
              annotations = {
                summary     = "Falco metrics target is down"
                description = "Prometheus cannot scrape Falco on instance {{ $labels.instance }}; runtime detection on that node may be down."
              }
            },
            {
              alert = "FalcosidekickDown"
              expr  = "up{namespace=\"falco\", job=\"falco-falcosidekick\"} == 0"
              "for" = "10m"
              labels = {
                severity  = "critical"
                component = "falco"
              }
              annotations = {
                summary     = "Falcosidekick is unreachable"
                description = "Prometheus cannot scrape falcosidekick on {{ $labels.instance }}; Falco events are not forwarded to Alertmanager."
              }
            }
          ]
        }
      ]
    }
  }
}
