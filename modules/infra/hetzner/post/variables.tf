## ============================================================================================= ##
#  modules/infra/hetzner/post/variables.tf                                                        #
#                                                                                                 #
#  Inputs for the Hetzner post stage --- creates servers and optional firewall.                   #
#                                                                                                 #
#    enabled        --- Enable this module                                                        #
#    config         --- Configuration object                                                      #
#      cluster_name --- Cluster name used for resource labels                                     #
#      dualstack    --- Enable public IPv6 on nodes                                               #
#      firewall     --- Firewall toggle and rule list                                             #
#      image_ids    --- Hetzner image IDs per architecture (amd64 + arm64)                        #
#      nodes        --- Node definitions: name, role, type, location, taints                      #
#    secrets        --- Sensitive configuration                                                   #
#      api_token    --- Hetzner Cloud API token                                                   #
#                                                                                                 #
#    Dependency outputs (passed separately):                                                      #
#      machine_configurations --- Per-node rendered configs from talos/pre (used as user_data)    #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Hetzner post-stage configuration"
  type = object({
    cluster_name = string
    dualstack    = bool
    firewall = object({
      enabled = bool
      rules = list(object({
        short_name  = string
        description = string
        protocol    = string
        direction   = string
        port        = string
        source_ips  = list(string)
      }))
    })
    image_ids = object({
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
      name     = string
      role     = string
      type     = string
      location = string
      taints   = list(string)
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

variable "machine_configurations" {
  description = "Per-node machine configuration strings --- from talos/pre output, keyed by node name; used as user_data on first boot"
  type        = map(string)
  sensitive   = true
}