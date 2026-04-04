## ============================================================================================= ##
#  modules/manifests/core/cnpg/variables.tf                                                       #
#                                                                                                 #
#    enabled              --- Enable this module                                                  #
#    config               --- Configuration object                                                #
#      controlplane_count --- Number of replicas (should match controlplane node count)           #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "CloudNativePG configuration"
  type = object({
    controlplane_count = number
  })
}