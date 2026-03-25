## ============================================================================================= ##
#  modules/infra/tailscale/post/variables.tf                                                      #
#                                                                                                 #
#  Inputs for the Tailscale post stage --- discovers device IPs after nodes join the tailnet.     #
#                                                                                                 #
#    enabled          --- Enable this module                                                      #
#    config           --- Configuration object                                                    #
#      dualstack      --- Also resolve IPv6 Tailscale addresses                                   #
#    secrets          --- Sensitive configuration                                                 #
#      client_id      --- OAuth client ID - used to delete devices on destroy                     #
#      client_secret  --- OAuth client secret - used to delete devices on destroy                 #
#      tailnet        --- Tailnet name                                                            #
#                                                                                                 #
#    Dependency outputs (passed via deps variable):                                               #
#      deps.nodes --- Node map with name and role (from hetzner/post)                             #
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
    client_id     = string
    client_secret = string
    tailnet       = string
  })
  sensitive = true
}

variable "deps" {
  description = "Outputs from upstream modules that are needed for this module"
  type = object({
    nodes = map(object({
      name = string
      role = string
    }))
  })
}

variable "rootvars" {
  description = "Root configuration from parent stack"
  type        = any
  default     = {}
}