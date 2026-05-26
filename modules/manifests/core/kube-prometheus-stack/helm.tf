## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/helm.tf                                           #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "kube-prometheus-stack"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "kube-prometheus-stack"
  version         = "85.2.2"
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
      value = "ReadWriteMany"
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
    }
  ]
  values = [yamlencode({
    alertmanager = {
      config = {
        route = {
          routes = concat(
            [{
              match = {
                alertname = "Watchdog"
              }
              receiver = "null"
            }],
            (try(var.secrets.alertmanager.discord_webhook_url, "") != "") ? [{
              receiver = "discord"
              continue = true
            }] : [],
            var.config.gotify_enabled ? [{
              receiver = "gotify"
              continue = true
            }] : []
          )
        }
        receivers = concat(
          [{ name = "null" }],
          (try(var.secrets.alertmanager.discord_webhook_url, "") != "") ? [{
            name = "discord"
            discord_configs = [{
              webhook_url   = var.secrets.alertmanager.discord_webhook_url
              send_resolved = true
              title         = "{{ if eq .Status \"firing\" }}Firing{{ else }}Resolved{{ end }}: {{ .Alerts | len }} alert(s)"
              message       = <<-EOT
                {{ range $i, $alert := .Alerts }}{{- if $i }}---{{ end }}
                **Alert:** {{ $alert.Labels.alertname }}
                **Severity:** {{ $alert.Labels.severity | toUpper }}
                {{- if $alert.Labels.instance }}
                **Instance:** `{{ $alert.Labels.instance }}`
                {{- end }}
                **Description:** {{ $alert.Annotations.description }}
                {{- if $alert.Labels }}
                **Labels:**
                ```{{ printf "%-15s | %s" "label" "value" }}
                ----------------+-----------------------------------
                {{ range $alert.Labels.SortedPairs }}{{ printf "%-15s | %s" .Name .Value }}
                {{ end }}```
                {{- end }}
                {{ end }}
              EOT
            }]
          }] : [],
          var.config.gotify_enabled ? [{
            name = "gotify"
            webhook_configs = [{
              url           = "http://alertmanager-gotify-bridge.gotify.svc.cluster.local:8080/gotify_webhook"
              send_resolved = true
            }]
          }] : []
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
  })]
  depends_on = [kubernetes_namespace_v1.this]
}