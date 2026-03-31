## ============================================================================================= ##
#  modules/manifests/core/longhorn/helm.tf                                                        #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "longhorn"
  repository      = "https://charts.longhorn.io"
  chart           = "longhorn"
  version         = var.chart_version
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  values = [
    <<-EOF
      image:
        longhorn:
          instanceManager:
            tag: v1.11.0-hotfix-1
          manager:
            tag: v1.11.0-hotfix-1
      longhornUI:
        replicas: 3
      preUpgradeChecker:
        jobEnabled: false
        upgradeVersionCheck: false
    EOF
  ]
  depends_on = [kubernetes_namespace_v1.this]
}
