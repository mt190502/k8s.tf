## ============================================================================================= ##
#  modules/manifests/core/dnsutils/variables.tf                                                   #
#                                                                                                 #
#  Inputs for the dnsutils manifests                                                              #
#                                                                                                 #
#    enabled        --- Enable this module                                                        #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}