## ============================================================================================= ##
#  modules/manifests/core/longhorn/helm.tf                                                        #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "longhorn"
  repository      = "https://charts.longhorn.io"
  chart           = "longhorn"
  version         = "1.11.1"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  set = [
    {
      name  = "longhornUI.replicas"
      value = 3
    },
    {
      name  = "preUpgradeChecker.jobEnabled"
      value = false
    },
    {
      name  = "preUpgradeChecker.upgradeVersionCheck"
      value = false
    }
  ]
  depends_on = [kubernetes_namespace_v1.this]
}
