## ============================================================================================= ##
#  modules/manifests/core/longhorn/variables.tf                                                   #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    secrets             --- Secrets for this module                                              #
#      access_key_id     --- Access key ID for S3-compatible storage                              #
#      endpoints         --- Endpoints for S3-compatible storage                                  #
#      secret_access_key --- Secret access key for S3-compatible storage                          #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "secrets" {
  description = "Secrets for this module"
  type = object({
    access_key_id     = string
    endpoints         = string
    secret_access_key = string
  })
  sensitive = true
}
