## ============================================================================================= ##
#  modules/manifests/settings/ci/rbac.tf                                                          #
## ============================================================================================= ##
resource "kubernetes_service_account_v1" "ci" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = var.config.service_account_name
    namespace = var.config.namespace
  }
  automount_service_account_token = false
}

resource "kubernetes_role_v1" "ci" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "ci-deployer"
    namespace = var.config.namespace
  }
  rule {
    api_groups = [""]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding_v1" "ci" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "ci-deployer-binding"
    namespace = var.config.namespace
  }
  subject {
    kind      = "ServiceAccount"
    name      = var.config.service_account_name
    namespace = var.config.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.ci[0].metadata[0].name
  }
}

resource "kubernetes_cluster_role_v1" "ci" {
  count = var.enabled ? 1 : 0
  metadata {
    name = "ci-deployer"
  }
  rule {
    api_groups = [""]
    resources  = ["namespaces", "nodes", "persistentvolumes"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets", "configmaps", "events", "persistentvolumeclaims", "services", "endpoints", "pods", "serviceaccounts"]
    verbs      = ["*"]
  }
  rule {
    api_groups = ["apps", "batch", "networking.k8s.io", "gateway.networking.k8s.io", "traefik.io", "postgresql.cnpg.io", "psmdb.percona.com", "longhorn.io", "monitoring.coreos.com", "cert-manager.io"]
    resources  = ["*"]
    verbs      = ["*"]
  }
  rule {
    api_groups = ["apiextensions.k8s.io", "rbac.authorization.k8s.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "ci" {
  count = var.enabled ? 1 : 0
  metadata {
    name = "ci-deployer"
  }
  subject {
    kind      = "ServiceAccount"
    name      = var.config.service_account_name
    namespace = var.config.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.ci[0].metadata[0].name
  }
}