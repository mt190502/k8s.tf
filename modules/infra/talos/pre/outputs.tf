## ============================================================================================= ##
#  modules/infra/talos/pre/outputs.tf                                                             #
#                                                                                                 #
#  Outputs for the Talos pre stage --- consumed by hetzner/post and talos/post.                   #
#                                                                                                 #
#    machine_configurations --- Per-node rendered machine config strings, keyed by node name      #
#    machine_secrets        --- Talos machine secrets (TLS creds); passed to talos/post           #
## ============================================================================================= ##
output "machine_configurations" {
  description = "Per-node machine configuration strings --- keyed by node name"
  value = {
    for k, v in data.talos_machine_configuration.nodes : k => v.machine_configuration
  }
  sensitive = true
}

output "machine_secrets" {
  description = "Talos machine secrets --- passed to talos/post for apply and bootstrap"
  value       = try(talos_machine_secrets.this[0], null)
  sensitive   = true
}