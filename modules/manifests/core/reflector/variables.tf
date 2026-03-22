## ============================================================================================= ##
#  modules/manifests/core/reflector/variables.tf                                                  #
#                                                                                                 #
#    enabled                          --- Enable this module                                      #
#    config                           --- Configuration object                                    #
#      wildcard_reflection_namespaces --- Namespaces to sync secrets/configmaps to                #
#    versions                         --- Version configuration                                   #
#      chart                          --- Reflector Helm chart version                            #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Reflector configuration"
  type = object({
    wildcard_reflection_namespaces = list(string)
  })
  default = {
    wildcard_reflection_namespaces = []
  }
}

variable "versions" {
  description = "Reflector version configuration"
  type = object({
    chart = string
  })
}