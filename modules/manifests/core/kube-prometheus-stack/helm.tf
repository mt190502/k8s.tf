## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/helm.tf                                           #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  version         = "88.2.0"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  wait            = false
  skip_crds       = true
  upgrade_install = true
  set = [
    {
      name  = "alertmanager.config.global.resolve_timeout"
      value = "5m"
    },
    {
      name  = "alertmanager.alertmanagerSpec.logFormat"
      value = "json"
    },
    {
      name  = "crds.enabled"
      value = "false"
    },
    {
      name  = "defaultRules.rules.kubeProxy"
      value = "false"
    },
    {
      name  = "grafana.persistence.enabled"
      value = "true"
    },
    {
      name  = "grafana.persistence.accessModes[0]"
      value = "ReadWriteOnce"
    },
    {
      name  = "grafana.persistence.size"
      value = var.config.storage_size
    },
    {
      name  = "grafana.route.main.enabled"
      value = "true"
    },
    {
      name  = "grafana.route.main.apiVersion"
      value = "gateway.networking.k8s.io/v1"
    },
    {
      name  = "grafana.route.main.kind"
      value = "HTTPRoute"
    },
    {
      name  = "grafana.route.main.hostnames[0]"
      value = "${var.config.hostname}.${var.config.domain}"
    },
    {
      name  = "grafana.route.main.parentRefs[0].name"
      value = var.config.gateway_name
    },
    {
      name  = "grafana.route.main.parentRefs[0].namespace"
      value = var.config.gateway_namespace
    },
    {
      name  = "grafana.route.main.matches[0].path.type"
      value = "PathPrefix"
    },
    {
      name  = "grafana.route.main.matches[0].path.value"
      value = "/"
    },
    {
      name  = "kubeProxy.enabled"
      value = "false"
    },
    {
      name  = "prometheus.prometheusSpec.logFormat"
      value = "json"
    }
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
    grafana = {
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
