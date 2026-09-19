## ============================================================================================= ##
#  modules/manifests/core/longhorn/recurringjobs.tf                                               #
#                                                                                                 #
#  Scheduled Longhorn snapshots and backups for volumes in the default recurring-job group.       #
#  The backup job requires Longhorn's default backup target to be configured.                     #
## ============================================================================================= ##
resource "kubernetes_manifest" "recurring_snapshot" {
  manifest = {
    apiVersion = "longhorn.io/v1beta2"
    kind       = "RecurringJob"
    metadata = {
      name      = "every-6h-snapshot"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      name        = "every-6h-snapshot"
      cron        = "0 */6 * * *"
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

  depends_on = [helm_release.this]
}

resource "kubernetes_manifest" "recurring_backup" {
  manifest = {
    apiVersion = "longhorn.io/v1beta2"
    kind       = "RecurringJob"
    metadata = {
      name      = "monthly-backup"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
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

  depends_on = [helm_release.this]
}
