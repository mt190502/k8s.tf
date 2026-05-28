## ============================================================================================= ##
#  modules/manifests/core/mongodb-community-operator/variables.tf                                 #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable MongoDB Community Operator"
  type        = bool
  default     = true
}
