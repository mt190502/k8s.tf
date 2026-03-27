## ============================================================================================= ##
#  modules/manifests/core/cnpg/variables.tf                                                       #
#                                                                                                 #
#    enabled              --- Enable this module                                                  #
#    config               --- Configuration object                                                #
#      controlplane_count --- Number of replicas (should match controlplane node count)           #
#    chart_version        --- CloudNativePG Helm chart version                                    #
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

variable "chart_version" {
  description = "CloudNativePG Helm chart version"
  type        = string
  default     = ""
}