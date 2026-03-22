## ============================================================================================= ##
#  modules/infra/hetzner/post/variables.tf                                                        #
#                                                                                                 #
#  Inputs for the Hetzner post stage --- creates servers and optional firewall.                   #
#                                                                                                 #
#    enabled        --- Enable this module                                                        #
#    config         --- Configuration object                                                      #
#      assignments  --- Node-to-architecture/location mapping rules                               #
#      cluster_name --- Cluster name used for resource labels                                     #
#      dualstack    --- Enable public IPv6 on nodes                                               #
#      firewall     --- Firewall toggle and rule list                                             #
#      images       --- Hetzner image IDs per architecture (amd64 + arm64)                        #
#      nodes        --- Node definitions: name, role, arch, location, image_id, server_type...    #
#      private_network --- Private network configuration (enabled, cidr)                          #
#    secrets        --- Sensitive configuration                                                   #
#      api_token    --- Hetzner Cloud API token                                                   #
#                                                                                                 #
#    Dependency outputs (passed via deps variable):                                               #
#      talos.machine_configurations --- Per-node rendered configs (used as user_data)             #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Hetzner post-stage configuration"
  type = object({
    assignments = list(object({
      selector = object({
        role = string
      })
      architecture = string
      strategy     = string
      locations    = list(string)
    }))
    cluster_name = string
    dualstack    = bool
    private_network = object({
      enabled = bool
      cidr    = string
    })
    firewall = object({
      enabled = bool
      rules = list(object({
        short_name  = string
        description = string
        protocol    = string
        port        = string
        source_ips  = optional(list(string))
      }))
    })
    images = object({
      amd64 = object({
        id   = string
        code = string
      })
      arm64 = object({
        id   = string
        code = string
      })
    })
    nodes = list(object({
      name        = string
      role        = string
      arch        = string
      location    = string
      image_id    = string
      server_type = string
      taints      = list(string)
    }))
  })
}

variable "secrets" {
  description = "Hetzner post-stage secrets"
  type = object({
    api_token = string
  })
  sensitive = true
}

variable "deps" {
  description = "Outputs from upstream modules that are needed for this module"
  type = object({
    talos = object({
      machine_configurations = map(string)
    })
  })
}

variable "rootvars" {
  description = "Root configuration from parent stack"
  type        = any
  default     = {}
}