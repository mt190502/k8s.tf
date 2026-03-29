## ============================================================================================= ##
#  modules/manifests/core/cert-manager/outputs.tf                                                 #
#                                                                                                 #
#  Outputs for the Cert Manager module --- Gateway name and namespace for use by                  #
#  testing suite and other modules.                                                               #
#                                                                                                 #
#    gateway_name          --- Name of the Gateway resource (cilium gateway or traefik-gateway)   #
#    gateway_namespace     --- Namespace where the Gateway is deployed                            #
#    certificate_name      --- Name of the wildcard TLS certificate secret                        #
#    certificate_namespace --- Namespace where the TLS certificate secret is stored               #
## ============================================================================================= ##
output "gateway_name" {
  description = "Name of the Gateway resource"
  value       = var.config.preferred_gateway == "cilium" ? "cilium-gateway" : "${var.config.preferred_gateway}-gateway"
}

output "gateway_namespace" {
  description = "Namespace where the Gateway resource is deployed"
  value       = var.config.preferred_gateway == "cilium" ? kubernetes_namespace_v1.this.metadata[0].name : "${var.config.preferred_gateway}-system"
}

output "certificate_name" {
  description = "Name of the wildcard TLS certificate secret"
  value       = local.certificate_name
}

output "certificate_namespace" {
  description = "Namespace where the TLS certificate secret is stored"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}