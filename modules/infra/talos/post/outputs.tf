## ============================================================================================= ##
#  modules/infra/talos/post/outputs.tf                                                            #
#                                                                                                 #
#  Outputs for the Talos post stage --- kubeconfig and talosconfig written to disk by hooks.      #
#                                                                                                 #
#    kubeconfig           --- Raw kubeconfig for the cluster (sensitive)                          #
#    talosconfig          --- Rendered talosconfig (sensitive)                                    #
#    client_configuration --- Resolved Talos client config block (endpoints + nodes)              #
## ============================================================================================= ##
output "kubeconfig" {
  description = "Raw kubeconfig for the cluster"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration (talosconfig) --- rendered by data.talos_client_configuration"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "client_configuration" {
  description = "Rendered Talos client configuration block --- endpoint and node list resolved"
  value       = data.talos_client_configuration.this.client_configuration
  sensitive   = true
}
