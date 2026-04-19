## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/variables.tf                                      #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      basic_auth        --- Enable basic authentication for Grafana (only with Traefik)          #
#      domain            --- Base domain for HTTPRoute hostname                                   #
#      gateway_name      --- Gateway name (from cert-manager)                                     #
#      gateway_namespace --- Gateway namespace (from cert-manager)                                #
#      hostname          --- HTTPRoute hostname subdomain (e.g., "app" -> app.{domain})           #
#      preferred_gateway --- Preferred Gateway for basic auth (e.g., "traefik")                   #
#      storage_size      --- Volume size for main application (e.g., "1Gi")                       #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Application configuration"
  type = object({
    basic_auth        = optional(bool, false)
    domain            = optional(string)
    gateway_name      = optional(string)
    gateway_namespace = optional(string)
    hostname          = optional(string)
    preferred_gateway = optional(string, "cilium")
    storage_size      = optional(string, "1Gi")
  })
  default = {}
}

variable "secrets" {
  description = "Application secrets"
  type        = map(map(string))
  sensitive   = true
  default     = {}
}