## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/pre/main.tf                                       #
#                                                                                                 #
#  Installs Prometheus Operator CRDs only (ServiceMonitor, PodMonitor, etc.)                      #
#  This allows other modules (cert-manager) to use ServiceMonitor before                          #
#  kube-prometheus-stack is fully deployed.                                                       #
## ============================================================================================= ##
resource "helm_release" "prometheus_operator_crds" {
  name            = "prometheus-operator-crds"
  repository      = "oci://ghcr.io/prometheus-community/charts"
  chart           = "prometheus-operator-crds"
  version         = "28.0.1"
  upgrade_install = true
}