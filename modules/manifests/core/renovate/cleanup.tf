## ============================================================================================= ##
#  modules/manifests/core/renovate/cleanup.tf                                                     #
#                                                                                                 #
#  Daily cleanup of the Renovate cache volume. Every run deletes the cloned repositories          #
#  but leaves their directory trees behind: the 1 Gi volume (ext4, 65,536 inodes) slowly          #
#  fills with empty directories while holding almost no files, until the                          #
#  KubePersistentVolumeInodesFillingUp alert fires (2026-11-12: 97% of inodes used by             #
#  61,432 empty directories on a volume with 1,785 files and 256 MB of data). This job            #
#  deletes empty directories that have been idle for more than two minutes, so a run              #
#  started concurrently by the 15-minute Renovate CronJob is never touched; its fresh             #
#  directories still have a recent modification time. The RWO volume is mounted in place          #
#  (same node, via the PV's node affinity), so no detach/attach churn is caused.                  #
#  lost+found is excluded: the filesystem needs it for fsck.                                      #
#  The same predicate was validated live before this job existed; after one manual run            #
#  inode usage dropped from 97% to 6%.                                                            #
## ============================================================================================= ##
resource "kubernetes_cron_job_v1" "cache_cleanup" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-cache-cleanup"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    labels = {
      "app.kubernetes.io/name" = var.config.name
    }
  }
  spec {
    schedule                      = var.config.cleanup_schedule
    timezone                      = var.config.timezone
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
        backoff_limit              = 0
        active_deadline_seconds    = 600
        ttl_seconds_after_finished = 86400
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name" = var.config.name
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
            container {
              name    = "${var.config.name}-cache-cleanup"
              image   = "alpine:3.24.4"
              command = ["sh", "-c"]
              args = [
                "find /cache -mindepth 1 -type d -empty -mmin +2 ! -path '/cache/lost+found*' -delete; df -i /cache",
              ]
              resources {
                requests = {
                  cpu    = "10m"
                  memory = "16Mi"
                }
                limits = {
                  memory = "32Mi"
                }
              }
              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
                capabilities {
                  drop = ["ALL"]
                }
              }
              volume_mount {
                name       = "${var.config.name}-cache"
                mount_path = "/cache"
              }
            }
            volume {
              name = "${var.config.name}-cache"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim_v1.this[0].metadata[0].name
              }
            }
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_persistent_volume_claim_v1.this,
  ]
}
