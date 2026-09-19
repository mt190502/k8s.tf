## ============================================================================================= ##
#  modules/manifests/apps/anki/pdb.tf                                                             #
#                                                                                                 #
#  Limits voluntary disruptions to one pod when the application runs multiple replicas.           #
## ============================================================================================= ##
resource "kubernetes_manifest" "pdb" {
  count = (var.enabled && try(coalesce(var.config.replicas, 1), 1) > 1) ? 1 : 0
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
