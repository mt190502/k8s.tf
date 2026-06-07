## ============================================================================================= ##
#  modules/manifests/core/descheduler/variables.tf                                                #
#                                                                                                 #
#    enabled                  --- Enable this module                                              #
#    config                   --- Configuration object                                            #
#      descheduling_interval  --- How often descheduler runs (e.g. "5m")                          #
#      replicas               --- Number of descheduler replicas (Deployment mode)                #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Descheduler configuration"
  type = object({
    descheduling_interval = optional(string, "5m")
    replicas              = optional(number, 2)
  })
}
