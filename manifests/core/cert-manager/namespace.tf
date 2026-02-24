resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "cert-manager"
  }
}