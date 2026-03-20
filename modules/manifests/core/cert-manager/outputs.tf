## ============================================================================================= ##
#  modules/manifests/core/cert-manager/outputs.tf                                                 #
#                                                                                                 #
#  Outputs for the Cert Manager post stage --- mostly Gateway name and namespace for use by       #
#  testing suite and other modules.                                                               #
#                                                                                                 #
#    gateway_name --- Name of the Gateway resource created by cert-manager                        #
#    namespace    --- Namespace where cert-manager is deployed                                    #
## ============================================================================================= ##
output "gateway_name" {
  description = "Name of the Gateway resource created by cert-manager for ACME HTTP-01 challenges"
  value       = local.gateway_name
}

output "namespace" {
  description = "Namespace where cert-manager is deployed"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}