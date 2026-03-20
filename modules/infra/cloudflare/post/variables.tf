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
#    Dependency outputs (passed separately):                                                      #
#      nodes, tailscale_ipv4, tailscale_ipv6                                                      #
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

variable "nodes" {
  description = "Map of all nodes with their Hetzner public IPs and role --- used for lb and apiserver DNS records"
  type = map(object({
    name         = string
    role         = string
    ipv4_address = string
    ipv6_address = string
  }))
}

variable "tailscale_ipv4" {
  description = "Map of node name to Tailscale IPv4 address"
  type        = map(string)
}

variable "tailscale_ipv6" {
  description = "Map of node name to Tailscale IPv6 address"
  type        = map(string)
  default     = {}
}