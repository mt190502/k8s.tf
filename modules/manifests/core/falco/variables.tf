## ============================================================================================= ##
#  modules/manifests/core/falco/variables.tf                                                      #
#                                                                                                 #
#    enabled                  --- Enable this module                                              #
#    config                   --- Configuration object                                            #
#      kps_namespace          --- Namespace where the Kube Prometheus Stack is deployed           #
#      falcosidekick_enabled  --- Deploy falcosidekick and forward events to Alertmanager         #
#      minimum_priority       --- Minimum Falco priority forwarded to Alertmanager                #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = false
}

variable "config" {
  description = "Falco configuration"
  type = object({
    kps_namespace         = string,
    falcosidekick_enabled = optional(bool, true),
    minimum_priority      = optional(string, "error"),
  })
}
