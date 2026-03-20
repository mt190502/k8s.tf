## ============================================================================================= ##
#  modules/infra/cloudflare/post/outputs.tf                                                       #
#                                                                                                 #
#  Outputs for the Cloudflare post stage --- DNS record FQDNs.                                    #
#                                                                                                 #
#    apiserver_fqdn --- API server FQDN  (cluster_url.apiserver -> k8s.<dns_domain>)              #
#    main_fqdn      --- Main cluster FQDN (cluster_url.main     -> <dns_domain>)                  #
#    wildcard_fqdn  --- Wildcard target   (*.cluster_url.dns    -> *.<dns_domain>)                #
## ============================================================================================= ##
output "apiserver_fqdn" {
  description = "Fully qualified domain name of the API server"
  value       = var.config.cluster_url.apiserver
}

output "main_fqdn" {
  description = "Fully qualified domain name of the main cluster endpoint (LB)"
  value       = var.config.cluster_url.main
}

output "wildcard_fqdn" {
  description = "Wildcard DNS record target"
  value       = "*.${var.config.cluster_url.dns}"
}
