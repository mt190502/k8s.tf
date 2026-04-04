## ============================================================================================= ##
#  modules/manifests/core/traefik/variables.tf                                                    #
#                                                                                                 #
#    enabled               --- Enable this module                                                 #
#    config                --- Configuration object                                               #
#      gateway_name        --- Gateway resource name                                              #
#      dns_domain          --- Base domain for wildcard certificate                               #
#      tls                 --- TLS configuration (injected from cert-manager dependency)          #
#        secret_name       --- Wildcard TLS secret name                                           #
#        secret_namespace  --- Namespace where the TLS secret exists                              #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Traefik configuration"
  type = object({
    gateway_name = optional(string, "traefik-gateway")
    dns_domain   = optional(string, "local")
    tls = optional(object({
      secret_name      = string
      secret_namespace = string
    }))
  })
  default = {}
}