## ============================================================================================= ##
#  modules/manifests/apps/gotify/variables.tf                                                     #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      basic_auth        --- Enable basic authentication support (only for Traefik Gateway)       #
#      domain            --- Base domain for HTTPRoute hostname                                   #
#      env               --- Environment variables (map of key-value)                             #
#      gateway_name      --- Gateway name (from cert-manager)                                     #
#      gateway_namespace --- Gateway namespace (from cert-manager)                                #
#      hostname          --- HTTPRoute hostname subdomain (e.g., "app" -> app.{domain})           #
#      name              --- Application name (used for resources)                                #
#      port              --- Container port                                                       #
#      preferred_gateway --- Preferred Gateway for basic auth (e.g., "traefik")                   #
#      replicas          --- Desired replica count (for Deployment/StatefulSet)                   #
#      resources         --- Resource requests and limits for the application                     #
#        limits          --- Resource limits for the application (cpu, memory)                    #
#        requests        --- Resource requests for the application (cpu, memory)                  #
#      storage_size      --- Volume size for main application                                     #
#    secrets             --- Secrets object (map of sensitive values)                             #
#      app               --- Application secrets (password, etc.)                                 #
#      bridge            --- Bridge secrets (gotify_token for alertmanager-gotify-bridge)         #
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
    chart             = optional(string)
    domain            = optional(string)
    env               = optional(map(string))
    gateway_name      = optional(string)
    gateway_namespace = optional(string)
    hostname          = optional(string)
    name              = optional(string, "gotify")
    port              = optional(number, 80)
    preferred_gateway = optional(string, "cilium")
    replicas          = optional(number, 1)
    resources = optional(object({
      limits   = optional(map(string))
      requests = optional(map(string))
    }))
    storage_size = optional(string, "1Gi")
  })
  default = {}
}

variable "secrets" {
  description = "Application secrets"
  type        = map(map(string))
  sensitive   = true
  default     = {}
}