## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/helm.tf                                           #
## ============================================================================================= ##
locals {
  gotify_info_routes = var.config.gotify_enabled ? [
    for name, endpoint in var.config.gotify_bridge_endpoints : {
      receiver = "gotify-${name}"
      match    = { severity = "info" }
      continue = true
    } if name == "alertmanager-info"
  ] : []
  gotify_regular_routes = var.config.gotify_enabled ? [
    for name, endpoint in var.config.gotify_bridge_endpoints : {
      receiver = "gotify-${name}"
      matchers = ["severity!=\"info\""]
      continue = true
    } if name != "loki" && name != "alertmanager-info"
  ] : []
  discord_adapter_enabled = trimspace(var.config.discord_adapter_endpoint) != ""
}

resource "helm_release" "this" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  version         = "91.7.1"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  wait            = false
  skip_crds       = true
  upgrade_install = true
  set = [
    { name = "alertmanager.alertmanagerSpec.externalUrl", value = "http://kube-prometheus-stack-alertmanager.${kubernetes_namespace_v1.this.metadata[0].name}.svc.cluster.local:9093", },
    { name = "alertmanager.alertmanagerSpec.logFormat", value = "json", },
    { name = "alertmanager.alertmanagerSpec.resources.limits.cpu", value = "250m", },
    { name = "alertmanager.alertmanagerSpec.resources.limits.memory", value = "64Mi", },
    { name = "alertmanager.alertmanagerSpec.resources.requests.cpu", value = "10m", },
    { name = "alertmanager.alertmanagerSpec.resources.requests.memory", value = "48Mi", },
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
    { name = "defaultRules.disabled.CPUThrottlingHigh", value = true, },
    { name = "defaultRules.rules.kubeApiserverAvailability", value = false, },
    { name = "defaultRules.rules.kubeApiserverBurnrate", value = false, },
    { name = "defaultRules.rules.kubeProxy", value = "false", },
    { name = "grafana.persistence.accessModes[0]", value = "ReadWriteOnce", },
    { name = "grafana.persistence.enabled", value = "true", },
    { name = "grafana.persistence.size", value = var.config.storage_size, },
    { name = "grafana.resources.limits.memory", value = "1312Mi", },
    { name = "grafana.resources.requests.cpu", value = "25m", },
    { name = "grafana.resources.requests.memory", value = "352Mi", },
    { name = "grafana.route.main.apiVersion", value = "gateway.networking.k8s.io/v1", },
    { name = "grafana.route.main.enabled", value = "true", },
    { name = "grafana.route.main.hostnames[0]", value = "${var.config.hostname}.${var.config.domain}", },
    { name = "grafana.route.main.kind", value = "HTTPRoute", },
    { name = "grafana.route.main.matches[0].path.type", value = "PathPrefix", },
    { name = "grafana.route.main.matches[0].path.value", value = "/", },
    { name = "grafana.route.main.parentRefs[0].name", value = var.config.gateway_name, },
    { name = "grafana.route.main.parentRefs[0].namespace", value = var.config.gateway_namespace, },
    { name = "grafana.sidecar.resources.limits.memory", value = "128Mi", },
    { name = "grafana.sidecar.resources.requests.cpu", value = "10m", },
    { name = "grafana.sidecar.resources.requests.memory", value = "96Mi", },
    { name = "kube-state-metrics.resources.limits.memory", value = "256Mi", },
    { name = "kube-state-metrics.resources.requests.cpu", value = "10m", },
    { name = "kube-state-metrics.resources.requests.memory", value = "64Mi", },
    { name = "kubeProxy.enabled", value = "false", },
    { name = "prometheus-node-exporter.resources.limits.memory", value = "32Mi", },
    { name = "prometheus-node-exporter.resources.requests.cpu", value = "10m", },
    { name = "prometheus-node-exporter.resources.requests.memory", value = "16Mi", },
    { name = "prometheus.prometheusSpec.externalUrl", value = "http://kube-prometheus-stack-prometheus.${kubernetes_namespace_v1.this.metadata[0].name}.svc.cluster.local:9090", },
    { name = "prometheus.prometheusSpec.logFormat", value = "json", },
    { name = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues", value = false, },
    { name = "prometheus.prometheusSpec.resources.limits.memory", value = "2Gi", },
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
    { name = "prometheus.route.main.parentRefs[0].sectionName", value = "srv-websecure", },
    { name = "prometheusOperator.admissionWebhooks.patch.resources.limits.memory", value = "64Mi", },
    { name = "prometheusOperator.admissionWebhooks.patch.resources.requests.cpu", value = "10m", },
    { name = "prometheusOperator.admissionWebhooks.patch.resources.requests.memory", value = "16Mi", },
    { name = "prometheusOperator.prometheusConfigReloader.resources.limits.memory", value = "32Mi", },
    { name = "prometheusOperator.prometheusConfigReloader.resources.requests.cpu", value = "10m", },
    { name = "prometheusOperator.prometheusConfigReloader.resources.requests.memory", value = "16Mi", },
    { name = "prometheusOperator.resources.limits.memory", value = "128Mi", },
    { name = "prometheusOperator.resources.requests.cpu", value = "50m", },
    { name = "prometheusOperator.resources.requests.memory", value = "48Mi", },
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
          group_by        = ["alertname", "namespace", "severity"]
          group_wait      = "30s"
          group_interval  = "5m"
          repeat_interval = "15m"
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
                local.discord_adapter_enabled ? [{
                  receiver = "discord"
                  continue = true
                }] : [],
                local.gotify_info_routes,
                local.gotify_regular_routes,
                [{ receiver = "null" }]
              )
            }],
            [{
              match_re = {
                alertname = "Miniflux.*"
              }
              repeat_interval = "6h"
              routes = concat(
                local.discord_adapter_enabled ? [{
                  receiver = "discord"
                  continue = true
                }] : [],
                local.gotify_info_routes,
                local.gotify_regular_routes,
                [{ receiver = "null" }]
              )
            }],
            [{
              match = {
                alertname = "TraefikHighLatency"
              }
              repeat_interval = "1h"
              routes = concat(
                local.discord_adapter_enabled ? [{
                  receiver = "discord"
                  continue = true
                }] : [],
                local.gotify_info_routes,
                local.gotify_regular_routes,
                [{ receiver = "null" }]
              )
            }],
            local.discord_adapter_enabled ? [{
              receiver = "discord"
              continue = true
            }] : [],
            var.config.gotify_enabled ? [
              for name, endpoint in var.config.gotify_bridge_endpoints : {
                receiver = "gotify-${name}"
                match    = { alertname = "LokiErrorLog" }
              } if name == "loki"
            ] : [],
            local.gotify_info_routes,
            local.gotify_regular_routes
          )
        }
        receivers = concat(
          [{ name = "null" }],
          local.discord_adapter_enabled ? [{
            name = "discord"
            webhook_configs = [{
              url           = var.config.discord_adapter_endpoint
              send_resolved = true
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
            metadata = {
              labels = {
                "recurring-job.longhorn.io/source"                 = "enabled"
                "recurring-job-group.longhorn.io/no-recurring-job" = "enabled"
              }
            }
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
        affinity = var.config.prometheus_node != null ? {
          nodeAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                preference = {
                  matchExpressions = [
                    {
                      key      = "kubernetes.io/hostname"
                      operator = "In"
                      values   = [var.config.prometheus_node]
                    }
                  ]
                }
              }
            ]
          }
        } : null
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
