## ============================================================================================= ##
#  modules/infra/cloudflare/post/variables.tf                                                     #
#                                                                                                 #
#  Inputs for the Cloudflare post stage --- creates DNS records for the cluster.                  #
#                                                                                                 #
#    enabled            --- Enable this module                                                    #
#    config             --- Configuration object                                                  #
#      cluster_url      --- Cluster FQDNs                                                         #
#        dns            --- DNS domain for services (e.g., srv.example.com)                       #
#        main           --- Main cluster FQDN for load balancer (e.g., example.com)               #
#        apiserver      --- API server FQDN (e.g., k8s.example.com)                               #
#      dualstack        --- Also create AAAA records for IPv6                                     #
#    secrets            --- Sensitive configuration                                               #
#      api_token        --- Cloudflare API token                                                  #
#      zone_id          --- Cloudflare Zone ID                                                    #
#    deps               --- Dependency outputs from upstream modules                              #
#      nodes            --- Map of nodes with IPs from hetzner/post                               #
#        name           --- Node hostname                                                         #
#        role           --- controlplane or worker                                                #
#        ipv4_address   --- Public IPv4 address                                                   #
#        ipv6_address   --- Public IPv6 address                                                   #
#      tailscale        --- Tailscale device IPs (preferred for controlplane)                     #
#        ipv4_addresses --- Map of Tailscale IPv4 addresses                                       #
#        ipv6_addresses --- Map of Tailscale IPv6 addresses                                       #
#    rootvars           --- Root configuration from parent stack                                  #
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