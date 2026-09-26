## ============================================================================================= ##
#  modules/manifests/core/longhorn/helm.tf                                                        #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "longhorn"
  repository      = "https://charts.longhorn.io"
  chart           = "longhorn"
  version         = "1.12.1"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  set = [
    { name = "longhornManager.resources.limits.memory", value = "448Mi", },
    { name = "longhornManager.resources.requests.cpu", value = "150m", },
    { name = "longhornManager.resources.requests.memory", value = "336Mi", },
    { name = "longhornUI.replicas", value = 3, },
    { name = "metrics.serviceMonitor.enabled", value = true, },
    { name = "preUpgradeChecker.jobEnabled", value = false, },
    { name = "preUpgradeChecker.upgradeVersionCheck", value = false, }
  ]
  values = [yamlencode({
    defaultSettings = {
      systemManagedCSIComponentsResourceLimits = jsonencode({
        csi-attacher            = { requests = { cpu = "10m", memory = "32Mi" }, limits = { memory = "32Mi" } }
        csi-provisioner         = { requests = { cpu = "10m", memory = "32Mi" }, limits = { memory = "32Mi" } }
        csi-resizer             = { requests = { cpu = "10m", memory = "32Mi" }, limits = { memory = "32Mi" } }
        csi-snapshotter         = { requests = { cpu = "10m", memory = "32Mi" }, limits = { memory = "32Mi" } }
        longhorn-csi-plugin     = { requests = { cpu = "10m", memory = "32Mi" }, limits = { memory = "64Mi" } }
        longhorn-liveness-probe = { requests = { cpu = "10m", memory = "32Mi" }, limits = { memory = "32Mi" } }
        node-driver-registrar   = { requests = { cpu = "10m", memory = "32Mi" }, limits = { memory = "32Mi" } }
      })
    }
  })]
  depends_on = [kubernetes_namespace_v1.this]
}
