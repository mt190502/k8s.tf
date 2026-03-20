## ============================================================================================= ##
#  modules/infra/tailscale/post/variables.tf                                                      #
#                                                                                                 #
#  Inputs for the Tailscale post stage --- discovers device IPs after nodes join the tailnet.     #
#                                                                                                 #
#    enabled          --- Enable this module                                                      #
#    config           --- Configuration object                                                    #
#      dualstack      --- Also resolve IPv6 Tailscale addresses                                   #
#    secrets          --- Sensitive configuration                                                 #
#      auth_key       --- Tailscale auth key for node registration                                #
#      client_id      --- OAuth client ID - used to delete devices on destroy                     #
#      client_secret  --- OAuth client secret - used to delete devices on destroy                 #
#      tailnet        --- Tailnet name                                                            #
#                                                                                                 #
#    Dependency outputs (passed separately):                                                      #
#      nodes          --- Node map with name and role (from hetzner/post)                         #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Tailscale post-stage configuration"
  type = object({
    dualstack = bool
  })
}

variable "secrets" {
  description = "Tailscale post-stage secrets"
  type = object({
    auth_key      = string
    client_id     = string
    client_secret = string
    tailnet       = string
  })
  sensitive = true
}

variable "nodes" {
  description = "Map of all nodes to discover via Tailscale (must match Talos hostname)"
  type = map(object({
    name = string
    role = string
  }))
}