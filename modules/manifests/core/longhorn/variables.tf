## ============================================================================================= ##
#  modules/manifests/core/longhorn/variables.tf                                                   #
#                                                                                                 #
#    enabled       --- Enable this module                                                         #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}