## ============================================================================================= ##
#  modules/infra/cloudflare/post/variables.tf                                                     #
#                                                                                                 #
#  Inputs for the Cloudflare post stage --- creates DNS records for the cluster.                  #
#                                                                                                 #
#    enabled       --- Enable this module                                                         #
#    config        --- Configuration object                                                       #
#      cluster_url --- Cluster FQDNs: main, apiserver, dns                                        #
#      dualstack   --- Also create AAAA records                                                   #
#    secrets       --- Sensitive configuration                                                    #
#      api_token   --- Cloudflare API token                                                       #
#      zone_id     --- Cloudflare Zone ID                                                         #
#                                                                                                 #
#    Dependency outputs (passed via deps variable):                                               #
#      nodes (name, role, ipv4_address, ipv6_address)                                             #
#      tailscale.ipv4_addresses, tailscale.ipv6_addresses                                         #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Cloudflare post-stage configuration"
  type = object({
    cluster_url = object({
      dns       = string
      main      = string
      apiserver = string
    })
    dualstack = bool
  })
}

variable "secrets" {
  description = "Cloudflare post-stage secrets"
  type = object({
    api_token = string
    zone_id   = string
  })
  sensitive = true
}

variable "deps" {
  description = "Outputs from upstream modules that are needed for this module"
  type = object({
    nodes = map(object({
      name         = string
      role         = string
      ipv4_address = string
      ipv6_address = string
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