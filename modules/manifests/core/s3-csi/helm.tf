## ============================================================================================= ##
#  modules/manifests/core/s3-csi/helm.tf                                                          #
#                                                                                                 #
#  Helm Release for deploying applications via Helm charts.                                       #
#  Configure repository, chart name, values, and set parameters.                                  #
#                                                                                                 #
#  Usage: Add set blocks manually for your chart values:                                          #
#    set { name = "image.tag" value = var.image_version }                                         #
#    set { name = "service.port" value = var.config.port }                                        #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "aws-mountpoint-s3-csi-driver"
  repository      = "https://awslabs.github.io/mountpoint-s3-csi-driver"
  chart           = "aws-mountpoint-s3-csi-driver"
  version         = "2.8.0"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  set = [
    { name = "awsAccessSecret.accessKey", value = "access_key", },
    { name = "awsAccessSecret.keyId", value = "key_id", },
    { name = "awsAccessSecret.name", value = kubernetes_secret_v1.garage_credentials.metadata[0].name, },
    { name = "controller.resources.limits.memory", value = "64Mi", },
    { name = "controller.resources.requests.cpu", value = "10m", },
    { name = "controller.resources.requests.memory", value = "40Mi", },
    { name = "mountpointPod.createNamespace", value = false, },
    { name = "mountpointPod.namespace", value = kubernetes_namespace_v1.this.metadata[0].name, },
    { name = "node.defaultTolerations", value = true, },
    { name = "node.tolerateAllTaints", value = true, },
    { name = "node.seLinuxOptions", value = null, },
  ]
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.garage_credentials,
  ]
}
