## ============================================================================================= ##
#  modules/manifests/core/testing/variables.tf                                                    #
#                                                                                                 #
#  Inputs for the testing suite                                                                   #
#                                                                                                 #
#    enabled        --- Enable this module                                                        #
#    config         --- Configuration object                                                      #
#      domain       --- Base domain for test endpoints                                            #
#      gateway_name --- Name of the Gateway resource created by cert-manager                      #
#      namespace    --- Namespace where cert-manager is deployed                                  #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Testing suite configuration"
  type = object({
    domain       = string
    gateway_name = optional(string)
    namespace    = optional(string)
  })
}