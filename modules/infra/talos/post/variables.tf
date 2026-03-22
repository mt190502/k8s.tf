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
#    Dependency outputs (passed via deps variable):                                               #
#      talos.machine_configurations, talos.machine_secrets                                        #
#      nodes (name, role, arch, location, ipv4_address, ipv6_address, private_ip, taints)         #
#      tailscale.ipv4_addresses, tailscale.ipv6_addresses                                         #
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

variable "deps" {
  description = "Outputs from upstream modules that are needed for this module"
  type = object({
    talos = object({
      machine_configurations = map(string)
      machine_secrets = object({
        client_configuration = object({
          ca_certificate     = string
          client_certificate = string
          client_key         = string
        })
      })
    })
    nodes = map(object({
      name         = string
      role         = string
      arch         = string
      location     = string
      ipv4_address = string
      ipv6_address = string
      private_ip   = optional(string)
      taints       = list(string)
    }))
    tailscale = object({
      ipv4_addresses = map(string)
      ipv6_addresses = map(string)
    })
  })
}

variable "rootvars" {
  description = "Root configuration from parent stack"
  type        = any
  default     = {}
}