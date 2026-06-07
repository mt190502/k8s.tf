## ============================================================================================= ##
#  modules/manifests/apps/slimserve/variables.tf                                                  #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      basic_auth        --- Enable basic authentication support (only for Traefik Gateway)       #
#      dirs              --- Directories to mount (used in PVC configuration)                     #
#      domain            --- Base domain for HTTPRoute hostname                                   #
#      env               --- Environment variables (map of key-value)                             #
#      gateway_name      --- Gateway name (from cert-manager)                                     #
#      gateway_namespace --- Gateway namespace (from cert-manager)                                #
#      hostname          --- HTTPRoute hostname subdomain (e.g., "app" -> app.{domain})           #
#      name              --- Application name (used for resources)                                #
#      persistence       --- Object for configuring persistent storage (optional)                 #
#        bucket_name     --- S3 bucket name for persistent storage                                #
#        s3_endpoint     --- S3 endpoint URL for persistent storage                               #
#        s3_region       --- S3 region for persistent storage                                     #
#        storage_size    --- Storage size for persistent storage                                  #
#      port              --- Container port                                                       #
#      preferred_gateway --- Preferred Gateway for basic auth (e.g., "traefik")                   #
#      replicas          --- Desired replica count (for Deployment/StatefulSet)                   #
#      resources         --- Resource requests and limits for the application                     #
#        limits          --- Resource limits for the application (cpu, memory)                    #
#        requests        --- Resource requests for the application (cpu, memory)                  #
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
    dirs              = optional(string, "/data")
    domain            = optional(string)
    env               = optional(map(string))
    gateway_name      = optional(string)
    gateway_namespace = optional(string)
    hostname          = optional(string)
    name              = optional(string, "slimserve")
    persistence = optional(object({
      enabled      = optional(bool, false)
      bucket_name  = optional(string, "slimserve")
      s3_endpoint  = optional(string)
      s3_region    = optional(string)
      storage_size = optional(string, "1T")
    }))
    port              = optional(number, 8080)
    preferred_gateway = optional(string, "cilium")
    replicas          = optional(number, 1)
    resources = optional(object({
      limits   = optional(map(string))
      requests = optional(map(string))
    }))
  })
  default = {}
}

variable "secrets" {
  description = "Application secrets"
  type        = map(map(any))
  sensitive   = true
  default     = {}
}
