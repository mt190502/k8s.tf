## ============================================================================================= ##
#  modules/manifests/apps/slimserve/pdb.tf                                                        #
## ============================================================================================= ##
resource "kubernetes_manifest" "pdb" {
  count = local.clustered ? 1 : 0
  manifest = {
    apiVersion = "policy/v1"
    kind       = "PodDisruptionBudget"
    metadata = {
      name      = var.config.name
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      maxUnavailable = 1
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = var.config.name
        }
      }
    }
  }
  depends_on = [kubernetes_namespace_v1.this]
}
