## ============================================================================================= ##
#  modules/manifests/core/longhorn/variables.tf                                                   #
#                                                                                                 #
#    enabled  --- Enable this module                                                              #
#    versions --- Version configuration                                                           #
#      chart  --- Longhorn Helm chart version                                                     #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "versions" {
  description = "Longhorn version configuration"
  type = object({
    chart = string
  })
}