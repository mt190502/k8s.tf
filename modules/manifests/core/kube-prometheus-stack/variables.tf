## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/variables.tf                                      #
#                                                                                                 #
#    enabled       --- Enable this module                                                         #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}