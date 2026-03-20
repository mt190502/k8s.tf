## ============================================================================================= ##
#  modules/manifests/core/testing/variables.tf                                                    #
#                                                                                                 #
#  Inputs for the testing suite                                                                   #
#                                                                                                 #
#    config         --- Configuration object                                                      #
#      gateway_name --- Name of the Gateway resource created by cert-manager                      #
#      namespace    --- Namespace where cert-manager is deployed                                  #
## ============================================================================================= ##
variable "config" {
  description = "Testing suite configuration"
  type = object({
    domain       = string
    gateway_name = string
    namespace    = string
  })
}