## ============================================================================================= ##
#  modules/manifests/core/tailscale-operator/variables.tf                                         #
#                                                                                                 #
#    enabled                          --- Enable this module                                      #
#    config                           --- Tailscale Operator configuration                        #
#      subnet_router_advertised_cidrs --- List of CIDR blocks to advertise via the Subnet Router  #
#    secrets                          --- Sensitive configuration                                 #
#      client_id                      --- Tailscale client ID                                     #
#      client_secret                  --- Tailscale client secret                                 #
#      auth_key                       --- Tailscale authentication key                            #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "tailscale-operator configuration"
  type = object({
    subnet_router_advertised_cidrs = list(string)
  })
}

variable "secrets" {
  description = "tailscale-operator secrets"
  type = object({
    auth_key      = string
    client_id     = string
    client_secret = string
  })
  sensitive = true
}