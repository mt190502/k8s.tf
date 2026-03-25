## ============================================================================================= ##
#  modules/infra/talos/post/variables.tf                                                          #
#                                                                                                 #
#  Inputs for the Talos post stage --- applies configs, bootstraps etcd, retrieves kubeconfig.    #
#                                                                                                 #
#    enabled                        --- Enable this module                                        #
#    config                         --- Configuration object                                      #
#      cluster_name                 --- Cluster name (for talos_client_configuration)             #
#      cluster_endpoint             --- API server hostname/IP, no scheme or port                 #
#      dualstack                    --- When true, IPv6 addresses are included in the node list   #
#      first_controlplane           --- Name of the first controlplane node (bootstrap target)    #
#                                                                                                 #
#    deps                           --- Outputs from upstream modules                             #
#      talos.machine_configurations --- Per-node rendered machine config strings                  #
#      talos.machine_secrets        --- Talos TLS credentials (client_configuration)              #
#      nodes                        --- Node metadata from hetzner/post (optional)                #
#      tailscale.ipv4_addresses     --- Tailscale IPv4 addresses per node                         #
#      tailscale.ipv6_addresses     --- Tailscale IPv6 addresses per node                         #
#      node_ips                     --- Computed node IPs for talosctl                            #
#                                                                                                 #
#    rootvars                       --- Root configuration from parent stack                      #
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

variable "deps" {
  description = "Outputs from upstream modules that are needed for this module"
  type = object({
    talos = object({
      machine_configurations = map(string)
      machine_secrets = optional(object({
        client_configuration = object({
          ca_certificate     = string
          client_certificate = string
          client_key         = string
        })
      }))
    })
    nodes = optional(map(object({
      name         = string
      role         = string
      arch         = string
      location     = string
      ipv4_address = string
      ipv6_address = string
      private_ip   = optional(string)
      taints       = list(string)
    })))
    tailscale = optional(object({
      ipv4_addresses = map(string)
      ipv6_addresses = map(string)
    }))
    node_ips = map(string)
  })
}

variable "rootvars" {
  description = "Root configuration from parent stack"
  type        = any
  default     = {}
}