## ============================================================================================= ##
#  modules/manifests/core/alloy/variables.tf                                                      #
#                                                                                                 #
#    enabled              --- Enable this module                                                  #
#    config               --- Configuration object                                                #
#      kps_namespace      --- Namespace where the Kube Prometheus Stack is deployed               #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Alloy configuration"
  type = object({
    kps_namespace = string,
  })
}
