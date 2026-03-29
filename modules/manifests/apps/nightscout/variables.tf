## ============================================================================================= ##
#  modules/manifests/apps/nightscout/variables.tf                                                 #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      domain            --- Base domain for HTTPRoute hostname                                   #
#      env               --- Environment variables (map of key-value)                             #
#      gateway_name      --- Gateway name (from cert-manager)                                     #
#      gateway_namespace --- Gateway namespace (from cert-manager)                                #
#      hostname          --- HTTPRoute hostname subdomain (e.g., "app" -> app.{domain})           #
#      image             --- Container image (e.g., "nginx")                                      #
#      mongo             --- MongoDB related options                                              #
#        limits          --- Resource limits for mongo instances (cpu, memory)                    #
#        requests        --- Resource requests for mongo instances (cpu, memory)                  #
#        replicas        --- Desired mongo instance count                                         #
#        storage_size    --- Volume size for mongo instances                                      #
#      name              --- Application name (used for resources)                                #
#      port              --- Container port                                                       #
#      replicas          --- Desired replica count (for Deployment/StatefulSet)                   #
#      resources         --- Resource requests and limits for the application                     #
#        limits          --- Resource limits for the application (cpu, memory)                    #
#        requests        --- Resource requests for the application (cpu, memory)                  #
#    secrets             --- Secrets object (map of sensitive values)                             #
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
    image             = optional(string, "nightscout/cgm-remote-monitor")
    mongo = optional(object({
      limits       = optional(map(string))
      requests     = optional(map(string))
      replicas     = optional(number, 1)
      storage_size = optional(string, "1Gi")
    }))
    name     = optional(string, "nightscout")
    port     = optional(number, 1337)
    replicas = optional(number, 1)
    resources = optional(object({
      limits   = optional(map(string))
      requests = optional(map(string))
    }))
  })
  default = {}
}

variable "secrets" {
  description = "Application secrets"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "image_version" {
  description = "Application image version"
  type        = string
  default     = ""
}