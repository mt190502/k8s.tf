## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/variables.tf                                      #
#                                                                                                 #
#    enabled  --- Enable this module                                                              #
#    versions --- Version configuration                                                           #
#      chart  --- kube-prometheus-stack Helm chart version                                        #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "versions" {
  description = "kube-prometheus-stack version configuration"
  type = object({
    chart = string
  })
}