## ============================================================================================= ##
#  modules/manifests/core/cnpg/variables.tf                                                       #
#                                                                                                 #
#    enabled         --- Enable this module                                                       #
#    config          --- Configuration object                                                     #
#      replica_count --- Number of replicas (should match controlplane node count)                #
#    versions        --- Version configuration                                                    #
#      chart         --- CloudNativePG Helm chart version                                         #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "CloudNativePG configuration"
  type = object({
    replica_count = number
  })
  default = {
    replica_count = 1
  }
}

variable "versions" {
  description = "CloudNativePG version configuration"
  type = object({
    chart = string
  })
}