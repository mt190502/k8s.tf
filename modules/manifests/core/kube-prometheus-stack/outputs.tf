## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/outputs.tf                                        #
#                                                                                                 #
#  Outputs for the Kube Prometheus Stack module --- Namespace name for use by loki and alloy      #
#                                                                                                 #
#    namespace  --- Namespace where the Kube Prometheus Stack is deployed                         #
## ============================================================================================= ##
output "namespace" {
  description = "Namespace where the Kube Prometheus Stack is deployed"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}