## ============================================================================================= ##
#  modules/manifests/apps/redmine/variables.tf                                                    #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      domain            --- Base domain for HTTPRoute hostname                                   #
#      env               --- Environment variables (map of key-value)                             #
#      gateway_name      --- Gateway name (from cert-manager)                                     #
#      gateway_namespace --- Gateway namespace (from cert-manager)                                #
#      hostname          --- HTTPRoute hostname subdomain (e.g., "app" -> app.{domain})           #
#      image             --- Container image (e.g., "nginx")                                      #
#      name              --- Application name (used for resources)                                #
#      port              --- Container port                                                       #
#      pg                --- PostgreSQL related options                                           #
#        limits          --- Resource limits for postgres instances (cpu, memory)                 #
#        requests        --- Resource requests for postgres instances (cpu, memory)               #
#        replicas        --- Desired postgres instance count                                      #
#        storage_size    --- Volume size for postgres instances                                   #
#      replicas          --- Desired replica count (for Deployment/StatefulSet)                   #
#      resources         --- Resource requests and limits for the application                     #
#        limits          --- Resource limits for the application (cpu, memory)                    #
#        requests        --- Resource requests for the application (cpu, memory)                  #
#    secrets             --- Secrets object (map of sensitive values)                             #
#    storage_size        --- Volume size for main application                                     #
#    image_version       --- Image version tag                                                    #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Application configuration"
  type = object({
    domain            = optional(string)
    env               = optional(map(string))
    gateway_name      = optional(string)
    gateway_namespace = optional(string)
    hostname          = optional(string)
    image             = optional(string, "redmine")
    name              = optional(string, "redmine")
    port              = optional(number, 3000)
    pg = optional(object({
      limits       = optional(map(string))
      requests     = optional(map(string))
      replicas     = optional(number, 1)
      storage_size = optional(string, "1Gi")
    }))
    replicas = optional(number, 1)
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

variable "image_version" {
  description = "Application image version"
  type        = string
  default     = ""
}