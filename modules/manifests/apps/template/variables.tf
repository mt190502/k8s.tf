## ============================================================================================= ##
#  modules/manifests/apps/template/variables.tf                                                   #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      chart             --- (helm.tf) Helm chart name                                            #
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
#      pg                --- PostgreSQL related options                                           #
#        limits          --- Resource limits for postgres instances (cpu, memory)                 #
#        requests        --- Resource requests for postgres instances (cpu, memory)               #
#        replicas        --- Desired postgres instance count                                      #
#        storage_size    --- Volume size for postgres instances                                   #
#      replicas          --- Desired replica count (for Deployment/StatefulSet)                   #
#      repository        --- (helm.tf) Helm chart repo URL                                        #
#    secrets             --- Secrets object (map of sensitive values)                             #
#    storage_size        --- Volume size for main application                                     #
#    chart_version       --- (helm.tf) Helm chart version tag                                     #
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
    chart             = optional(string)
    domain            = optional(string)
    env               = optional(map(string))
    gateway_name      = optional(string)
    gateway_namespace = optional(string)
    hostname          = optional(string)
    image             = optional(string, "changeme/changeme")
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
    replicas     = optional(number, 1)
    repository   = optional(string, "https://changeme.local/helm-charts")
    storage_size = optional(string, "1Gi")
  })
  default = {}
}

variable "secrets" {
  description = "Application secrets"
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "chart_version" {
  description = "Helm chart version"
  type        = string
  default     = ""
}

variable "image_version" {
  description = "Application image version"
  type        = string
  default     = ""
}