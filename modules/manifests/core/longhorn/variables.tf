## ============================================================================================= ##
#  modules/manifests/core/longhorn/variables.tf                                                   #
#                                                                                                 #
#    enabled       --- Enable this module                                                         #
#    chart_version --- Longhorn Helm chart version                                                #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "Longhorn Helm chart version"
  type        = string
  default     = ""
}