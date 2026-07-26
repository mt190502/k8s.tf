## ============================================================================================= ##
#  modules/manifests/core/gotify/variables.tf                                                     #
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
#      pg                --- PostgreSQL related options                                           #
#        limits          --- Resource limits for postgres instances (cpu, memory)                 #
#        requests        --- Resource requests for postgres instances (cpu, memory)               #
#        replicas        --- Desired postgres instance count                                      #
#        storage_size    --- Volume size for postgres instances                                   #
#      port              --- Container port                                                       #
#      preferred_gateway --- Preferred Gateway for basic auth (e.g., "traefik")                   #
#      replicas          --- Desired replica count (for Deployment/StatefulSet)                   #
#      resources         --- Resource requests and limits for the application                     #
#        limits          --- Resource limits for the application (cpu, memory)                    #
#        requests        --- Resource requests for the application (cpu, memory)                  #
#      storage_size      --- Volume size for main application                                     #
#    secrets             --- Secrets object (map of sensitive values)                             #
#      app               --- Application secrets (password, etc.)                                 #
#      basic_auth        --- Basic auth credentials (only for Traefik Gateway)                    #
#        username        --- Basic auth username                                                  #
#        password_hash   --- Basic auth password hash (bcrypt)                                    #
#      bridges           --- Alertmanager bridges to create (key = bridge name, value = config)   #
#        token           --- Gotify application token for this bridge                             #
#      pg                --- PostgreSQL secrets                                                   #
#        password         --- PostgreSQL owner password                                           #
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
    pg = optional(object({
      limits       = optional(map(string))
      requests     = optional(map(string))
      replicas     = optional(number, 1)
      storage_size = optional(string, "1Gi")
    }))
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
  type = object({
    app = optional(map(string))
    basic_auth = optional(object({
      username      = string
      password_hash = string
    }))
    bridges = optional(map(object({ token = string })))
    pg = optional(object({
      password = string
    }))
  })
  sensitive = true
  default   = {}
}
