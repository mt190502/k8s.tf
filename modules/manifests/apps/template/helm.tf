## ============================================================================================= ##
#  modules/manifests/apps/template/helm.tf                                                        #
#                                                                                                 #
#  Helm Release for deploying applications via Helm charts.                                       #
#  Configure repository, chart name, values, and set parameters.                                  #
#                                                                                                 #
#  Usage: Add set blocks manually for your chart values:                                          #
#    set { name = "image.tag" value = var.image_version }                                         #
#    set { name = "service.port" value = var.config.port }                                        #
## ============================================================================================= ##
resource "helm_release" "this" {
  count            = (var.enabled && var.chart_version != "") ? 1 : 0
  name             = var.config.name
  namespace        = kubernetes_namespace_v1.this[0].metadata[0].name
  repository       = try(var.config.repository, "")
  chart            = try(var.config.chart, var.config.name)
  version          = var.chart_version
  create_namespace = false
  upgrade_install  = true

  # Add your chart values here:
  # set = [
  #   {
  #     name  = "image.tag"
  #     value = var.image_version
  #   }
  # ]

  depends_on = [kubernetes_namespace_v1.this]
}