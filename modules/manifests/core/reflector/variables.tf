## ============================================================================================= ##
#  modules/manifests/core/reflector/variables.tf                                                  #
#                                                                                                 #
#    enabled  --- Enable this module                                                              #
#    versions --- Version configuration                                                           #
#      chart  --- Reflector Helm chart version                                                    #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "versions" {
  description = "Reflector version configuration"
  type = object({
    chart = string
  })
}