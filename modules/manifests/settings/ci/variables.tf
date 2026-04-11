## ============================================================================================= ##
#  modules/manifests/settings/ci/variables.tf                                                     #
#                                                                                                 #
#    enabled                --- Enable this module                                                #
#    config                 --- Configuration object                                              #
#      apiserver            --- Kubernetes API server URL                                         #
#      cluster_name         --- Kubernetes cluster name                                           #
#      namespace            --- Kubernetes namespace for CI resources                             #
#      service_account_name --- Kubernetes service account name for CI resources                  #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = false
}

variable "config" {
  description = "CI kubeconfig and RBAC configuration"
  type = object({
    apiserver            = string
    cluster_name         = string
    namespace            = string
    service_account_name = string
  })
}