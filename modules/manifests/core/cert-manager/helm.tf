## ============================================================================================= ##
#  modules/manifests/core/cert-manager/helm.tf                                                    #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "cert-manager"
  repository      = "https://charts.jetstack.io"
  chart           = "cert-manager"
  version         = "v1.21.1"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  set = [
    {
      name  = "config.apiVersion"
      value = "controller.config.cert-manager.io/v1alpha1"
    },
    {
      name  = "config.kind"
      value = "ControllerConfiguration"
    },
    {
      name  = "config.enableGatewayAPI"
      value = true
    },
    {
      name  = "crds.enabled"
      value = true
    },
    {
      name  = "prometheus.enabled"
      value = true
    },
    {
      name  = "prometheus.servicemonitor.enabled"
      value = true
    }
  ]
  values = [yamlencode({
    extraArgs = [
      "--enable-certificate-owner-ref=true",
      "--dns01-recursive-nameservers-only",
      "--dns01-recursive-nameservers=1.1.1.1:53,9.9.9.9:53"
    ]
  })]
  depends_on = [kubernetes_secret_v1.this]
}
