## ============================================================================================= ##
#  modules/manifests/core/psmdb-operator/variables.tf                                             #
#                                                                                                 #
#    enabled  --- Enable this module                                                              #
#    versions --- Version configuration                                                           #
#      chart  --- PSMDB operator Helm chart version                                               #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "versions" {
  description = "PSMDB operator version configuration"
  type = object({
    chart = string
  })
}