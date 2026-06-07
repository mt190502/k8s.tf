## ============================================================================================= ##
#  modules/manifests/apps/slimserve/pv.tf                                                         #
#                                                                                                 #
#  PersistentVolume for applications requiring persistent storage.                                #
## ============================================================================================= ##
resource "kubernetes_persistent_volume_v1" "this" {
  count = var.enabled ? 1 : 0
  metadata {
    name = "${var.config.name}-pv"
  }
  spec {
    capacity = {
      storage = var.config.persistence.storage_size
    }
    access_modes       = ["ReadWriteMany"]
    storage_class_name = "longhorn"
    persistent_volume_source {
      csi {
        driver        = "s3.csi.aws.com"
        volume_handle = "${var.config.name}-volume"
        volume_attributes = {
          bucketName = var.config.persistence.bucket_name
        }
      }
    }
    mount_options = [
      "force-path-style",
      "endpoint-url=${var.config.persistence.s3_endpoint}",
      "region=${var.config.persistence.s3_region}",
      "allow-delete",
      "allow-other",
      "uid=1001",
      "gid=1001",
      "metadata-ttl=300",
      "negative-metadata-ttl=60",
      "max-threads=16",
    ]
    persistent_volume_reclaim_policy = "Retain"
    claim_ref {
      name      = "${var.config.name}-pvc"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
  }
  depends_on = [
    kubernetes_namespace_v1.this,
  ]
}
