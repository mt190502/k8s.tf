## ============================================================================================= ##
#  modules/manifests/core/atlantis/httproute.tf                                                   #
#                                                                                                 #
#  HTTPRoute is created by Helm chart via route.main values.                                      #
#  This file only contains basic_auth resources for Traefik.                                      #
## ============================================================================================= ##
resource "kubernetes_secret_v1" "basic_auth" {
  count = (var.enabled && var.config.basic_auth && var.config.preferred_gateway == "traefik") ? 1 : 0
  metadata {
    name      = "${var.config.name}-basic-auth"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  type = "Opaque"
  data = {
    users = "${var.secrets.basic_auth.username}:${var.secrets.basic_auth.password_hash}"
  }
}

resource "kubernetes_manifest" "basic_auth_middleware" {
  count = (var.enabled && var.config.basic_auth && var.config.preferred_gateway == "traefik") ? 1 : 0
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${var.config.name}-basic-auth"
      namespace = kubernetes_namespace_v1.this[0].metadata[0].name
    }
    spec = {
      basicAuth = {
        secret = kubernetes_secret_v1.basic_auth[0].metadata[0].name
      }
    }
  }
  depends_on = [kubernetes_secret_v1.basic_auth]
}