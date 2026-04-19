## ============================================================================================= ##
#  modules/manifests/apps/<<<template>>>/variables.tf                                             #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      basic_auth        --- Enable basic authentication support (only for Traefik Gateway)       #
#      chart             --- (helm.tf) Helm chart name                                            #
#      domain            --- Base domain for HTTPRoute hostname                                   #
#      env               --- Environment variables (map of key-value)                             #
#      gateway_name      --- Gateway name (from cert-manager)                                     #
#      gateway_namespace --- Gateway namespace (from cert-manager)                                #
#      hostname          --- HTTPRoute hostname subdomain (e.g., "app" -> app.{domain})           #
#      mongo             --- MongoDB related options                                              #
#        limits          --- Resource limits for mongo instances (cpu, memory)                    #
#        requests        --- Resource requests for mongo instances (cpu, memory)                  #
#        replicas        --- Desired mongo instance count                                         #
#        storage_size    --- Volume size for mongo instances                                      #
#      name              --- Application name (used for resources)                                #
#      port              --- Container port                                                       #
#      pg                --- PostgreSQL related options                                           #
#        limits          --- Resource limits for postgres instances (cpu, memory)                 #
#        requests        --- Resource requests for postgres instances (cpu, memory)               #
#        replicas        --- Desired postgres instance count                                      #
#        storage_size    --- Volume size for postgres instances                                   #
#      preferred_gateway --- Preferred Gateway for basic auth (e.g., "traefik")                   #
#      replicas          --- Desired replica count (for Deployment/StatefulSet)                   #
#      resources         --- Resource requests and limits for the application                     #
#        limits          --- Resource limits for the application (cpu, memory)                    #
#        requests        --- Resource requests for the application (cpu, memory)                  #
#      storage_size      --- Volume size for main application                                     #
#    secrets             --- Secrets object (map of sensitive values)                             #
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
    mongo = optional(object({
      limits       = optional(map(string))
      requests     = optional(map(string))
      replicas     = optional(number, 1)
      storage_size = optional(string, "1Gi")
    }))
    name = optional(string, "changeme")
    port = optional(number, 1234)
    pg = optional(object({
      limits       = optional(map(string))
      requests     = optional(map(string))
      replicas     = optional(number, 1)
      storage_size = optional(string, "1Gi")
    }))
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