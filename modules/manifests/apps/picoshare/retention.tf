## ============================================================================================= ##
#  modules/manifests/apps/picoshare/retention.tf                                                  #
#                                                                                                 #
#  Retention enforcer: clamps PicoShare's file lifetimes to a maximum of                           #
#  var.config.max_expiration_days and vacuums the database. PicoShare's own garbage               #
#  collector then deletes the expired entries (it runs every 7 hours while the app is up).         #
#                                                                                                 #
#  The job shares the application's ReadWriteOnce volume, so pod affinity keeps it on the same node. #
## ============================================================================================= ##
resource "kubernetes_config_map_v1" "retention" {
  count = (var.enabled && var.config.retention_enabled) ? 1 : 0
  metadata {
    name      = "${var.config.name}-retention"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    "retention.sh" = file("${path.module}/retention.sh")
  }
  depends_on = [kubernetes_namespace_v1.this]
}

resource "kubernetes_cron_job_v1" "retention" {
  count = (var.enabled && var.config.retention_enabled) ? 1 : 0
  metadata {
    name      = "${var.config.name}-retention"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name" = var.config.name
    }
  }
  spec {
    schedule                      = var.config.retention_schedule
    concurrency_policy            = "Forbid"
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
        backoff_limit              = 1
        active_deadline_seconds    = 900
        ttl_seconds_after_finished = 86400
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name" = var.config.name
            }
            annotations = {
              "checksum/script" = filesha256("${path.module}/retention.sh")
            }
          }
          spec {
            restart_policy = "Never"
            # The volume is ReadWriteOnce, so the job must run on the node where PicoShare runs.
            affinity {
              pod_affinity {
                required_during_scheduling_ignored_during_execution {
                  label_selector {
                    match_labels = {
                      "app.kubernetes.io/name" = var.config.name
                    }
                  }
                  topology_key = "kubernetes.io/hostname"
                }
              }
            }
            security_context {
              seccomp_profile {
                type = "RuntimeDefault"
              }
            }
            container {
              name    = "retention"
              image   = "alpine:3.24"
              command = ["/bin/sh", "-c"]
              # apk needs root inside the container to install the sqlite3 CLI.
              args = [
                "apk add --no-cache sqlite >/dev/null && exec /scripts/retention.sh"
              ]
              env {
                name  = "DB_PATH"
                value = "/data/store.db"
              }
              env {
                name  = "MAX_EXPIRATION_DAYS"
                value = tostring(var.config.max_expiration_days)
              }
              env {
                name  = "VACUUM"
                value = tostring(var.config.retention_vacuum)
              }
              # Always set resources: the cluster requires requests.cpu, requests.memory and limits.memory on every container.
              resources {
                limits = (try(var.config.retention_resources.limits, null) != null && var.config.retention_resources.limits != {}) ? var.config.retention_resources.limits : {
                  memory = "256Mi"
                }
                requests = (try(var.config.retention_resources.requests, null) != null && var.config.retention_resources.requests != {}) ? var.config.retention_resources.requests : {
                  cpu    = "50m"
                  memory = "64Mi"
                }
              }
              security_context {
                allow_privilege_escalation = false
              }
              volume_mount {
                name       = "${var.config.name}-data"
                mount_path = "/data"
              }
              volume_mount {
                name       = "${var.config.name}-retention"
                mount_path = "/scripts"
                read_only  = true
              }
            }
            volume {
              name = "${var.config.name}-data"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim_v1.this[0].metadata[0].name
              }
            }
            volume {
              name = "${var.config.name}-retention"
              config_map {
                name         = kubernetes_config_map_v1.retention[0].metadata[0].name
                default_mode = "0555"
              }
            }
          }
        }
      }
    }
  }
  lifecycle {
    precondition {
      condition     = var.config.max_expiration_days >= 1
      error_message = "config.max_expiration_days must be at least 1: PicoShare does not support sub-day file lifetimes."
    }
  }

  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_config_map_v1.retention,
    kubernetes_persistent_volume_claim_v1.this,
  ]
}
