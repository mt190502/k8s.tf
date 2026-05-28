## ============================================================================================= ##
#  modules/manifests/core/mongodb-community-operator/helm.tf                                      #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "mongodb-community-operator"
  repository      = "https://mongodb.github.io/helm-charts"
  chart           = "community-operator"
  version         = "0.13.0"
  namespace       = kubernetes_namespace_v1.this[0].metadata[0].name
  upgrade_install = true
  set = [
    {
      name  = "operator.watchNamespace"
      value = "*"
    }
  ]
  depends_on = [kubernetes_namespace_v1.this]
}
