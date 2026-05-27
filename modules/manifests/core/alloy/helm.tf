## ============================================================================================= ##
#  modules/manifests/core/alloy/helm.tf                                                           #
## ============================================================================================= ##
locals {
  # ---------------------------------------------------------------------------------------------- #
  #  Log format documentation for ALL apps — single source of truth.                              #
  #  Fields:                                                                                       #
  #    description  — app & logger type                                                           #
  #    samples      — actual kubectl log lines                                                    #
  #    json_support — whether the app can output JSON logs                                        #
  #    logql_filter — LogQL line filter to catch error lines                                      #
  #    stage_regex  — Alloy stage.regex expression to extract level (null if no level prefix)     #
  # ---------------------------------------------------------------------------------------------- #
  app_log_formats = {
    gotify = {
      description  = "Go standard logger, no JSON output"
      json_support = false
      samples = [
        "2026-05-27T04:16:46Z | 200 | 132.64µs | 10.244.1.205 | GET \"/\"",
        "2026/05/27 04:22:41 /src/gotify/database/client.go:63 SLOW SQL >= 200ms",
        "[201.825ms] [rows:2] UPDATE `clients` SET ...",
      ]
      logql_filter = "(?i)(error|fatal|panic)"
      stage_regex  = null
    }
    anki = {
      description  = "Rust env_logger with ANSI-colored structured output, no JSON"
      json_support = false
      samples = [
        "[2m2026-05-26T20:10:39.567035Z[0m [32m INFO[0m [1mrequest{[0m[3muri[0m[2m=[0m\"/sync/beta\"[1m}[0m[2m:[0m finished [3melap_ms[0m[2m=[0m0 [3mhttpstatus[0m[2m=[0m405",
      ]
      logql_filter = "(?i)(error|fatal|panic)"
      stage_regex  = "(?:\\\\x1b\\\\[\\\\d+m)?\\\\d{4}-\\\\d{2}-\\\\d{2}T\\\\d{2}:\\\\d{2}:\\\\d{2}\\\\.\\\\d+Z(?:\\\\x1b\\\\[0m)?(?:\\\\x1b\\\\[\\\\d+m)?\\\\s+(?P<level>[A-Z]+)"
    }
    nightscout = {
      description  = "Node.js console.log, free-form text, no JSON output"
      json_support = false
      samples = [
        "WS: dbAdd client ID: 6pwuybIcOYShOMBJAAYE  data: { collection: 'devicestatus', ... }",
        "tick 2026-05-27T05:35:39.691Z",
        "Load Complete: sgvs:557, treatments:3, profiles:1, devicestatus:537, ...",
      ]
      logql_filter = "(?i)(error|fatal|panic)"
      stage_regex  = null
    }
    radicale = {
      description  = "Python logging module to stderr, no JSON output"
      json_support = false
      samples = [
        "[2026-05-27 05:09:47 +0000] [11/Thread-5832 (process_request_thread)] [INFO] Successful login: 'mt190502' (htpasswd)",
      ]
      logql_filter = "(?i)(error|fatal|panic|critical)"
      stage_regex  = "\\\\[\\\\d{4}-\\\\d{2}-\\\\d{2} \\\\d{2}:\\\\d{2}:\\\\d{2} [+-]\\\\d{4}\\\\]\\\\s+\\\\[\\\\d+/Thread-\\\\d+ \\\\([^)]+\\\\)\\\\]\\\\s+\\\\[(?P<level>[A-Z]+)\\\\]"
    }
    redmine = {
      description  = "Rails Ruby Logger, no JSON output (would need lograge gem + custom image)"
      json_support = false
      samples = [
        "I, [2026-05-27T05:13:23.802476 #1]  INFO -- : [bc8e2639-18ac-4176-8b75-db6d535feab2] Started GET \"/icalendar/...\"",
      ]
      logql_filter = "(?i)(error|fatal|panic)"
      stage_regex  = "^\\\\w,\\\\s+\\\\[\\\\d{4}-\\\\d{2}-\\\\d{2}T\\\\d{2}:\\\\d{2}:\\\\d{2}\\\\.\\\\d+ #\\\\d+\\\\]\\\\s+(?P<level>\\\\w+)\\\\s+--"
    }
    umami = {
      description  = "Next.js/Node.js stderr, JavaScript stack traces, no JSON output"
      json_support = false
      samples = [
        "Error: Failed to find Server Action \"x\". This request might be from an older or newer deployment.",
        "    at ignore-listed frames",
      ]
      logql_filter = "^(Error|error|ERROR|Warning|warning|WARNING):"
      stage_regex  = null
    }
    syncstorage_rs = {
      description  = "Rust moz_json format (SYNC_HUMAN_LOGS=false), outputs JSON by default"
      json_support = true
      samples = [
        "{\"msg\":\"...\",\"level\":\"INFO\",\"ts\":\"...\"}",
      ]
      logql_filter = "\"level\":\\s*\"(error|fatal|panic)\""
      stage_regex  = null
    }
  }

  log_parsing_rules = {
    for name, cfg in local.app_log_formats : name => {
      app   = name
      regex = cfg.stage_regex
    } if cfg.stage_regex != null
  }
}

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
            level  = "info"
            format = "json"
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

          loki.process "pod_logs" {
            %{~for r in local.log_parsing_rules~}
            stage.match {
              selector = "{app=\"${r.app}\"}"
              stage.regex {
                expression = "${r.regex}"
              }
            }

            %{~endfor~}
            forward_to = [loki.write.default.receiver]
          }

          loki.source.kubernetes "pod_logs" {
            targets    = discovery.relabel.pod_logs.output
            forward_to = [loki.process.pod_logs.receiver]
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
