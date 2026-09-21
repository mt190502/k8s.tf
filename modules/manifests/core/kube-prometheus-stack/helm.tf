## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/helm.tf                                           #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  version         = "91.4.1"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  wait            = false
  skip_crds       = true
  upgrade_install = true
  set = [
    { name = "alertmanager.alertmanagerSpec.externalUrl", value = "http://kube-prometheus-stack-alertmanager.${kubernetes_namespace_v1.this.metadata[0].name}.svc.cluster.local:9093", },
    { name = "alertmanager.alertmanagerSpec.logFormat", value = "json", },
    { name = "alertmanager.config.global.resolve_timeout", value = "5m", },
    { name = "alertmanager.route.main.apiVersion", value = "gateway.networking.k8s.io/v1", },
    { name = "alertmanager.route.main.enabled", value = "true", },
    { name = "alertmanager.route.main.hostnames[0]", value = "${var.config.alertmanager_hostname}.${var.config.domain}", },
    { name = "alertmanager.route.main.kind", value = "HTTPRoute", },
    { name = "alertmanager.route.main.matches[0].path.type", value = "PathPrefix", },
    { name = "alertmanager.route.main.matches[0].path.value", value = "/", },
    { name = "alertmanager.route.main.parentRefs[0].name", value = var.config.gateway_name, },
    { name = "alertmanager.route.main.parentRefs[0].namespace", value = var.config.gateway_namespace, },
    { name = "alertmanager.route.main.parentRefs[0].sectionName", value = "srv-websecure", },
    { name = "crds.enabled", value = "false", },
    { name = "defaultRules.disabled.NodeDiskIOSaturation", value = true, },
    { name = "defaultRules.rules.kubeProxy", value = "false", },
    { name = "grafana.persistence.accessModes[0]", value = "ReadWriteOnce", },
    { name = "grafana.persistence.enabled", value = "true", },
    { name = "grafana.persistence.size", value = var.config.storage_size, },
    { name = "grafana.route.main.apiVersion", value = "gateway.networking.k8s.io/v1", },
    { name = "grafana.route.main.enabled", value = "true", },
    { name = "grafana.route.main.hostnames[0]", value = "${var.config.hostname}.${var.config.domain}", },
    { name = "grafana.route.main.kind", value = "HTTPRoute", },
    { name = "grafana.route.main.matches[0].path.type", value = "PathPrefix", },
    { name = "grafana.route.main.matches[0].path.value", value = "/", },
    { name = "grafana.route.main.parentRefs[0].name", value = var.config.gateway_name, },
    { name = "grafana.route.main.parentRefs[0].namespace", value = var.config.gateway_namespace, },
    { name = "kubeProxy.enabled", value = "false", },
    { name = "prometheus.prometheusSpec.externalUrl", value = "http://kube-prometheus-stack-prometheus.${kubernetes_namespace_v1.this.metadata[0].name}.svc.cluster.local:9090", },
    { name = "prometheus.prometheusSpec.logFormat", value = "json", },
    { name = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues", value = false, },
    { name = "prometheus.prometheusSpec.resources.limits.memory", value = "1536Mi", },
    { name = "prometheus.prometheusSpec.resources.requests.cpu", value = "250m", },
    { name = "prometheus.prometheusSpec.resources.requests.memory", value = "500Mi", },
    { name = "prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues", value = false, },
    { name = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues", value = false, },
    { name = "prometheus.route.main.apiVersion", value = "gateway.networking.k8s.io/v1", },
    { name = "prometheus.route.main.enabled", value = "true", },
    { name = "prometheus.route.main.hostnames[0]", value = "${var.config.prometheus_hostname}.${var.config.domain}", },
    { name = "prometheus.route.main.kind", value = "HTTPRoute", },
    { name = "prometheus.route.main.matches[0].path.type", value = "PathPrefix", },
    { name = "prometheus.route.main.matches[0].path.value", value = "/", },
    { name = "prometheus.route.main.parentRefs[0].name", value = var.config.gateway_name, },
    { name = "prometheus.route.main.parentRefs[0].namespace", value = var.config.gateway_namespace, },
    { name = "prometheus.route.main.parentRefs[0].sectionName", value = "srv-websecure", }
  ]
  values = [sensitive(yamlencode({
    alertmanager = {
      config = {
        global = {}
        inhibit_rules = [
          {
            source_match = {
              severity = "warning"
            }
            target_match = {
              severity = "info"
            }
            equal = ["namespace"]
          },
        ]
        route = {
          group_by        = ["alertname", "namespace", "pod", "container"]
          group_wait      = "1s"
          group_interval  = "1s"
          repeat_interval = "5m"
          routes = concat(
            [{
              match = {
                alertname = "Watchdog"
              }
              receiver = "null"
            }],
            [{
              match = {
                alertname = "InfoInhibitor"
              }
              receiver = "null"
            }],
            [{
              match = {
                alertname = "LonghornVolumeSpaceUsageHigh"
              }
              repeat_interval = "3h"
              routes = concat(
                (try(var.secrets.alertmanager.discord_webhook_url, "") != "") ? [{
                  receiver = "discord"
                  continue = true
                }] : [],
                var.config.gotify_enabled ? [
                  for name, endpoint in var.config.gotify_bridge_endpoints : {
                    receiver = "gotify-${name}"
                    continue = true
                  } if name != "loki"
                ] : [],
                [{ receiver = "null" }]
              )
            }],
            [{
              match = {
                alertname = "TraefikHighLatency"
              }
              repeat_interval = "1h"
              routes = concat(
                (try(var.secrets.alertmanager.discord_webhook_url, "") != "") ? [{
                  receiver = "discord"
                  continue = true
                }] : [],
                var.config.gotify_enabled ? [
                  for name, endpoint in var.config.gotify_bridge_endpoints : {
                    receiver = "gotify-${name}"
                    continue = true
                  } if name != "loki"
                ] : [],
                [{ receiver = "null" }]
              )
            }],
            (try(var.secrets.alertmanager.discord_webhook_url, "") != "") ? [{
              receiver = "discord"
              continue = true
            }] : [],
            var.config.gotify_enabled ? [
              for name, endpoint in var.config.gotify_bridge_endpoints : {
                receiver = "gotify-${name}"
                match    = { alertname = "LokiErrorLog" }
              } if name == "loki"
            ] : [],
            var.config.gotify_enabled ? [
              for name, endpoint in var.config.gotify_bridge_endpoints : {
                receiver = "gotify-${name}"
                continue = true
              } if name != "loki"
            ] : []
          )
        }
        receivers = concat(
          [{ name = "null" }],
          (try(var.secrets.alertmanager.discord_webhook_url, "") != "") ? [{
            name = "discord"
            discord_configs = [{
              webhook_url   = var.secrets.alertmanager.discord_webhook_url
              send_resolved = true
              title         = "{{ if eq .Status \"firing\" }}:fire: Firing{{ else }}:white_check_mark: Resolved{{ end }}: {{ .Alerts | len }} alert(s)"
              message       = <<-EOT
                {{ range .Alerts }}
                **Alert:** {{ .Labels.alertname }}
                **Severity:** {{ .Labels.severity | toUpper }}
                **Description:** {{ .Annotations.description }}
                **Labels:**
                ```{{ printf "%-15s | %s" "label" "value" }}
                ----------------+-----------------------------------
                {{- range .Labels.SortedPairs }}
                {{ printf "%-15s | %s" .Name .Value }}
                {{- end }}```
                {{ end }}
              EOT
            }]
          }] : [],
          var.config.gotify_enabled ? [
            for name, endpoint in var.config.gotify_bridge_endpoints : {
              name = "gotify-${name}"
              webhook_configs = [{
                url           = endpoint
                send_resolved = true
              }]
            }
          ] : []
        )
      }
    }
    prometheus = {
      prometheusSpec = {
        retention     = var.config.prometheus_retention
        retentionSize = var.config.prometheus_retention_size
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              accessModes = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = var.config.prometheus_storage_size
                }
              }
            }
          }
        }
      }
    }
    grafana = {
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }
          ]
        }
      }
      dashboards = {
        default = {
          atlantis       = { gnetId = 23419, revision = 1, datasource = "Prometheus", }
          cert_manager   = { gnetId = 11001, revision = 1, datasource = "Prometheus", }
          cloudnative_pg = { gnetId = 20417, revision = 4, datasource = "Prometheus", }
          loki           = { gnetId = 14055, revision = 5, datasource = "Loki", }
          longhorn       = { gnetId = 13032, revision = 6, datasource = "Prometheus", }
          traefik        = { gnetId = 17346, revision = 9, datasource = "Prometheus", }
        }
      }
      route = {
        main = {
          filters = var.config.basic_auth && var.config.preferred_gateway == "traefik" ? [
            {
              type = "ExtensionRef"
              extensionRef = {
                group = "traefik.io"
                kind  = "Middleware"
                name  = "${var.config.name}-basic-auth"
              }
            }
          ] : []
        }
      }
    }
  }))]
  depends_on = [kubernetes_namespace_v1.this]
}
