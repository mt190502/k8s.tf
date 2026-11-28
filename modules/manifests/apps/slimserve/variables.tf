## ============================================================================================= ##
#  modules/manifests/apps/slimserve/variables.tf                                                  #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      bucket_name       --- S3 bucket name to serve (Garage)                                     #
#      domain            --- Base domain for HTTPRoute hostname                                   #
#      env               --- Environment variables (map of key-value)                             #
#      gateway_name      --- Gateway name (from cert-manager)                                     #
#      gateway_namespace --- Gateway namespace (from cert-manager)                                #
#      hostname          --- HTTPRoute hostname subdomain (e.g., "app" -> app.{domain})           #
#      name              --- Application name (used for resources)                                #
#      port              --- Container port                                                       #
#      replicas          --- Desired replica count (keep 1 for the test deployment)               #
#      resources         --- Resource requests and limits for the application                     #
#        limits          --- Resource limits for the application (cpu, memory)                    #
#        requests        --- Resource requests for the application (cpu, memory)                  #
#      s3_endpoint       --- S3 endpoint URL for the bucket store (path-style)                    #
#      s3_region         --- S3 region for the bucket store                                       #
#    secrets             --- Secrets object (reused Garage S3 credentials from core/s3-csi)       #
#      access_key_id     --- S3 access key ID for Garage (from manifests.core.s3_csi)             #
#      secret_access_key --- S3 secret access key for Garage (from manifests.core.s3_csi)         #
#      release_cookie    --- Erlang cluster cookie, required above 1 replica                      #
#      secret_key_base   --- Fixed session signing key, required above 1 replica                  #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = false
}

variable "config" {
  description = "Application configuration"
  type = object({
    bucket_name       = optional(string, "files")
    domain            = optional(string)
    env               = optional(map(string))
    gateway_name      = optional(string)
    gateway_namespace = optional(string)
    hostname          = optional(string)
    name              = optional(string, "slimserve")
    port              = optional(number, 8080)
    replicas          = optional(number, 1)
    resources = optional(object({
      limits   = optional(map(string))
      requests = optional(map(string))
    }))
    s3_endpoint = optional(string)
    s3_region   = optional(string, "us-east-1")
  })
  default = {}
}

variable "secrets" {
  description = "Garage S3 credentials (reused from manifests.core.s3_csi)"
  type = object({
    access_key_id     = optional(string, "")
    release_cookie    = optional(string, "")
    secret_access_key = optional(string, "")
    secret_key_base   = optional(string, "")
  })
  sensitive = true
  default   = {}
}
