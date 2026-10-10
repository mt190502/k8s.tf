## ============================================================================================= ##
#  modules/manifests/core/renovate/github_app_token.tf                                            #
#                                                                                                 #
#  Token minter for the Renovate runner.                                                          #
#  Renovate only accepts a token (RENOVATE_TOKEN) and GitHub App installation tokens expire       #
#  after one hour, so every run mints a fresh one from the App ID, installation ID and key.       #
## ============================================================================================= ##
resource "kubernetes_config_map_v1" "token_minter" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-token-minter"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    "github_app_token.js" = file("${path.module}/github_app_token.js")
  }
  depends_on = [kubernetes_namespace_v1.this]
}
