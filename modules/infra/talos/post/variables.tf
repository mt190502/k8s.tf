## ============================================================================================= ##
#  modules/infra/talos/post/variables.tf                                                          #
#                                                                                                 #
#  Inputs for the Talos post stage --- applies configs, bootstraps etcd, retrieves kubeconfig.    #
#  Values come from talos/pre, hetzner/post, and tailscale/post outputs.                          #
#                                                                                                 #
#    enabled               --- Enable this module                                                 #
#    config                --- Configuration object                                               #
#      cluster_name        --- Cluster name (for talos_client_configuration)                      #
#      cluster_endpoint    --- API server hostname/IP, no scheme or port                          #
#      dualstack           --- When true, IPv6 addresses are included in the node list            #
#      first_controlplane  --- Name of the first controlplane node (bootstrap target)             #
#                                                                                                 #
#    Dependency outputs (passed separately):                                                      #
#      machine_configurations, machine_secrets, nodes, tailscale_ipv4, tailscale_ipv6             #
#                                                                                                 #
#    Terragrunt-only inputs (not passed to Terraform):                                            #
#      hetzner_enabled, tailscale_enabled --- Control dependency data flow from stack units       #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Talos post-stage configuration"
  type = object({
    cluster_name       = string
    cluster_endpoint   = string
    dualstack          = bool
    first_controlplane = string
  })
}

variable "machine_configurations" {
  description = "Per-node machine configuration strings --- from talos/pre output, keyed by node name; used as user_data on first boot"
  type        = map(string)
  sensitive   = true
}

variable "machine_secrets" {
  description = "Talos machine secrets object --- from talos/pre output (talos_machine_secrets resource)"
  type = object({
    client_configuration = object({
      ca_certificate     = string
      client_certificate = string
      client_key         = string
    })
  })
  sensitive = true
}

variable "nodes" {
  description = "Map of all nodes with role metadata --- from hetzner/post output, keyed by node name. Empty map when hetzner unit is disabled."
  type = map(object({
    name     = string
    role     = string
    type     = string
    location = string
    taints   = list(string)
  }))
}

variable "tailscale_ipv4" {
  description = "Map of node name to Tailscale IPv4 address --- from tailscale/post output. Empty map when hetzner or tailscale unit is disabled."
  type        = map(string)
  default     = {}
}

variable "tailscale_ipv6" {
  description = "Map of node name to Tailscale IPv6 address --- from tailscale/post output. Empty map when hetzner or tailscale unit is disabled, or dualstack is false."
  type        = map(string)
  default     = {}
}