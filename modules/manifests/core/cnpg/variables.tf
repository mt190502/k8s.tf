## ============================================================================================= ##
#  modules/manifests/core/cnpg/variables.tf                                                       #
#                                                                                                 #
#    enabled  --- Enable this module                                                              #
#    versions --- Version configuration                                                           #
#      chart  --- CloudNativePG Helm chart version                                                #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "versions" {
  description = "CloudNativePG version configuration"
  type = object({
    chart = string
  })
}