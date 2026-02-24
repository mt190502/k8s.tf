resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = "reflector-system"
  }
}