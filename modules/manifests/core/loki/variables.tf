## ============================================================================================= ##
#  modules/manifests/core/loki/variables.tf                                                       #
#                                                                                                 #
#    enabled              --- Enable this module                                                  #
#    config               --- Configuration object                                                #
#      s3                 --- S3 configuration for backup and restore operations                  #
#      endpoint           --- S3 endpoint URL (e.g., https://s3.amazonaws.com)                    #
#      region             --- S3 region (e.g., us-east-1)                                         #
#      force_path_style   --- Whether to use path-style URLs for S3 (true or false)               #
#      kps_namespace      --- Namespace where the Kube Prometheus Stack is deployed               #
#    secrets              --- Secrets object containing sensitive information                     #
#      access_key_id      --- S3 access key for authentication                                    #
#      secret_access_key  --- S3 secret key for authentication                                    #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Loki configuration"
  type = object({
    s3               = string,
    endpoint         = string,
    region           = string,
    force_path_style = bool,
    kps_namespace    = string,
  })
}

variable "secrets" {
  description = "Loki secrets"
  type = object({
    access_key_id     = string,
    secret_access_key = string,
  })
  sensitive = true
}
