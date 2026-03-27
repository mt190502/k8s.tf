## ============================================================================================= ##
#  modules/manifests/core/kube-prometheus-stack/variables.tf                                      #
#                                                                                                 #
#    enabled       --- Enable this module                                                         #
#    chart_version --- kube-prometheus-stack Helm chart version                                   #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = ""
}