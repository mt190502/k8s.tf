## ============================================================================================= ##
#  modules/manifests/core/atlantis/rbac.tf                                                        #
## ============================================================================================= ##
resource "kubernetes_cluster_role_v1" "atlantis_deployer" {
  count = var.enabled ? 1 : 0
  metadata {
    name = "${var.config.name}-deployer"
  }
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "atlantis_deployer" {
  count = var.enabled ? 1 : 0
  metadata {
    name = "${var.config.name}-deployer"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.atlantis_deployer[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = var.config.name
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
}
