## ============================================================================================= ##
#  modules/manifests/core/s3-csi/variables.tf                                                     #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      endpoint          --- S3 API endpoint (e.g., "https://s3.amazonaws.com")                   #
#      region            --- S3 region (e.g., "us-east-1")                                        #
#    secrets             --- Secrets object (map of sensitive values)                             #
#      access_key_id     --- S3 access key ID for Garage                                          #
#      secret_access_key --- S3 secret access key for Garage                                      #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Configuration for S3 CSI driver"
  type = object({
    endpoint = string
    region   = string
  })
}

variable "secrets" {
  description = "S3 credentials for Garage"
  type = object({
    access_key_id     = string
    secret_access_key = string
  })
  sensitive = true
}
