## ============================================================================================= ##
#  modules/manifests/core/longhorn/jobs/recurringjobs.tf                                          #
#                                                                                                 #
#  Scheduled Longhorn snapshots and backups for volumes in the default recurring-job group.       #
#  The backup job requires Longhorn's default backup target to be configured.                     #
#                                                                                                 #
#  Lives in its own unit because the RecurringJob CRDs ship with the Longhorn chart in            #
#  core/longhorn; planning these CRs there fails on a fresh install. Moving them here deletes     #
#  the old objects in core/longhorn and recreates them in this unit within one stack apply.       #
## ============================================================================================= ##
resource "kubernetes_manifest" "recurring_snapshot" {
  manifest = {
    apiVersion = "longhorn.io/v1beta2"
    kind       = "RecurringJob"
    metadata = {
      name      = "nightly-snapshot"
      namespace = "longhorn-system"
    }
    spec = {
      name        = "nightly-snapshot"
      cron        = "0 23 * * *"
      task        = "snapshot"
      retain      = 3
      concurrency = 1
      groups      = ["default"]
      labels = {
        "longhorn.io/recurring-job" = "true"
        "srv.mtaha.dev/automated"   = "true"
        "srv.mtaha.dev/terraform"   = "true"
      }
    }
  }
}

resource "kubernetes_manifest" "recurring_backup" {
  manifest = {
    apiVersion = "longhorn.io/v1beta2"
    kind       = "RecurringJob"
    metadata = {
      name      = "monthly-backup"
      namespace = "longhorn-system"
    }
    spec = {
      name        = "monthly-backup"
      cron        = "0 0 1 * *"
      task        = "backup"
      retain      = 12
      concurrency = 1
      groups      = ["default"]
      labels = {
        "longhorn.io/recurring-job" = "true"
        "srv.mtaha.dev/automated"   = "true"
        "srv.mtaha.dev/terraform"   = "true"
      }
    }
  }
}
