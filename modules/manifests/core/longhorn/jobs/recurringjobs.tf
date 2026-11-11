## ============================================================================================= ##
#  modules/manifests/core/longhorn/jobs/recurringjobs.tf                                          #
#                                                                                                 #
#  Scheduled Longhorn snapshots and backups for volumes in the default recurring-job group.       #
#  The backup job requires Longhorn's default backup target to be configured.                     #
#  Volumes labelled into the "trim" group (cache-like PVCs without snapshots: Prometheus TSDB,    #
#  Loki, trivy server) get a filesystem trim every six hours (03/09/15/21 UTC) that releases      #
#  blocks of deleted files. Without it such a volume grows to its full provisioned size on        #
#  every replica node: the Prometheus TSDB rewrites about 0.2 GB/h, so a daily or weekly trim     #
#  does not bound it.                                                                             #
#  The trim job is created before a replaced one is destroyed: when the last RecurringJob of      #
#  a group is deleted, Longhorn removes that group's label from every volume and PVC, so a        #
#  plain rename would silently drop all volumes out of the "trim" group.                          #
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

resource "kubernetes_manifest" "recurring_trim" {
  manifest = {
    apiVersion = "longhorn.io/v1beta2"
    kind       = "RecurringJob"
    metadata = {
      name      = "periodic-trim"
      namespace = "longhorn-system"
    }
    spec = {
      name        = "periodic-trim"
      cron        = "0 3,9,15,21 * * *"
      task        = "filesystem-trim"
      retain      = 0
      concurrency = 1
      groups      = ["trim"]
      labels = {
        "longhorn.io/recurring-job" = "true"
        "srv.mtaha.dev/automated"   = "true"
        "srv.mtaha.dev/terraform"   = "true"
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
