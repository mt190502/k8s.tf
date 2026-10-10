## ============================================================================================= ##
#  modules/manifests/core/renovate/cronjob.tf                                                     #
#                                                                                                 #
#  Scheduled self-hosted Renovate runner.                                                         #
#  An init container mints a short-lived GitHub App installation token (Renovate has no           #
#  native App-ID/private-key support) which the main container consumes as RENOVATE_TOKEN.        #
#                                                                                                 #
#  Docs: https://docs.renovatebot.com/examples/self-hosting/                                      #
## ============================================================================================= ##
resource "kubernetes_cron_job_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name" = var.config.name
    }
  }
  spec {
    schedule                      = var.config.schedule
    timezone                      = var.config.timezone
    concurrency_policy            = var.config.concurrency_policy
    starting_deadline_seconds     = 300
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3
    job_template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = var.config.name
        }
      }
      spec {
        backoff_limit              = 0
        active_deadline_seconds    = var.config.active_deadline_seconds
        ttl_seconds_after_finished = 86400
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name" = var.config.name
            }
            annotations = {
              "checksum/config" = sha256(join("", [
                filesha256("${path.module}/configmap.tf"),
                filesha256("${path.module}/cronjob.tf"),
                filesha256("${path.module}/github_app_token.js"),
              ]))
            }
          }
          spec {
            restart_policy = "Never"
            security_context {
              fs_group        = 1000
              run_as_group    = 1000
              run_as_non_root = true
              run_as_user     = 1000
              seccomp_profile {
                type = "RuntimeDefault"
              }
            }

            ## --------------------------------------------------------------------------------- ##
            #  Mint a GitHub App installation token (1h TTL) for the current run.                #
            ## --------------------------------------------------------------------------------- ##
            init_container {
              name    = "${var.config.name}-token"
              image   = "node:24-alpine"
              command = ["node", "/token-minter/github_app_token.js"]
              env {
                name = "APP_ID"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.this[0].metadata[0].name
                    key  = "app-id"
                  }
                }
              }
              env {
                name = "APP_INSTALLATION_ID"
                value_from {
                  secret_key_ref {
                    name = kubernetes_secret_v1.this[0].metadata[0].name
                    key  = "app-installation-id"
                  }
                }
              }
              env {
                name  = "PRIVATE_KEY_PATH"
                value = "/secrets/app-private-key"
              }
              env {
                name  = "TOKEN_PATH"
                value = "/shared/token"
              }
              security_context {
                allow_privilege_escalation = false
                capabilities {
                  drop = ["ALL"]
                }
              }
              volume_mount {
                name       = "${var.config.name}-shared"
                mount_path = "/shared"
              }
              volume_mount {
                name       = "${var.config.name}-secret"
                mount_path = "/secrets"
                read_only  = true
              }
              volume_mount {
                name       = "${var.config.name}-token-minter"
                mount_path = "/token-minter"
                read_only  = true
              }
            }

            ## --------------------------------------------------------------------------------- ##
            #  Run Renovate against every repository in scope.                                  #
            ## --------------------------------------------------------------------------------- ##
            container {
              name    = var.config.name
              image   = "ghcr.io/renovatebot/renovate:44.149.2"
              command = ["/bin/bash", "-c"]
              args = [
                "export RENOVATE_TOKEN=\"$(cat /shared/token)\"; exec renovate"
              ]
              env {
                name  = "RENOVATE_CONFIG_FILE"
                value = "/config/config.js"
              }
              env {
                name  = "RENOVATE_CACHE_DIR"
                value = "/tmp/renovate/cache"
              }
              env {
                name  = "RENOVATE_EXIT_CODE_FOR_ERRORS"
                value = "true"
              }
              env {
                name  = "LOG_FORMAT"
                value = "json"
              }
              env {
                name  = "LOG_LEVEL"
                value = var.config.log_level
              }
              env {
                name = "RENOVATE_GITHUB_COM_TOKEN"
                value_from {
                  secret_key_ref {
                    name     = kubernetes_secret_v1.this[0].metadata[0].name
                    key      = "github-com-token"
                    optional = true
                  }
                }
              }
              dynamic "env" {
                for_each = var.config.env != null ? var.config.env : {}
                content {
                  name  = env.key
                  value = env.value
                }
              }
              dynamic "resources" {
                for_each = var.config.resources != null ? [1] : []
                content {
                  limits = (var.config.resources.limits != null || var.config.resources.limits != {}) ? var.config.resources.limits : ((var.config.resources.requests == null || var.config.resources.requests == {}) ? {
                    cpu    = "250m"
                    memory = "512Mi"
                  } : {})
                  requests = (var.config.resources.requests != null || var.config.resources.requests != {}) ? var.config.resources.requests : ((var.config.resources.limits == null || var.config.resources.limits == {}) ? {
                    cpu    = "125m"
                    memory = "256Mi"
                  } : {})
                }
              }
              security_context {
                allow_privilege_escalation = false
                # Renovate installs toolchains and writes temp data outside the mounted volumes.
                read_only_root_filesystem = false
                capabilities {
                  drop = ["ALL"]
                }
              }
              volume_mount {
                name       = "${var.config.name}-shared"
                mount_path = "/shared"
              }
              volume_mount {
                name       = "${var.config.name}-config"
                mount_path = "/config"
                read_only  = true
              }
              volume_mount {
                name       = "${var.config.name}-cache"
                mount_path = "/tmp/renovate"
              }
            }

            volume {
              name = "${var.config.name}-shared"
              empty_dir {}
            }
            volume {
              name = "${var.config.name}-config"
              config_map {
                name = kubernetes_config_map_v1.configmap[0].metadata[0].name
              }
            }
            volume {
              name = "${var.config.name}-cache"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim_v1.this[0].metadata[0].name
              }
            }
            volume {
              name = "${var.config.name}-token-minter"
              config_map {
                name         = kubernetes_config_map_v1.token_minter[0].metadata[0].name
                default_mode = "0444"
              }
            }
            volume {
              name = "${var.config.name}-secret"
              secret {
                secret_name  = kubernetes_secret_v1.this[0].metadata[0].name
                default_mode = "0440"
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.this,
    kubernetes_config_map_v1.configmap,
    kubernetes_config_map_v1.token_minter,
    kubernetes_persistent_volume_claim_v1.this,
  ]
}
