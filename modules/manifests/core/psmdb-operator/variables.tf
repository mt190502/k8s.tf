## ============================================================================================= ##
#  modules/manifests/core/psmdb-operator/variables.tf                                             #
#                                                                                                 #
#    enabled       --- Enable this module                                                         #
#    chart_version --- PSMDB operator Helm chart version                                          #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "PSMDB operator Helm chart version"
  type        = string
  default     = ""
}