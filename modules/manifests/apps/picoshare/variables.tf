## ============================================================================================= ##
#  modules/manifests/apps/picoshare/variables.tf                                                  #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      domain            --- Base domain for HTTPRoute hostname                                   #
#      env               --- Environment variables (map of key-value)                             #
#      gateway_name      --- Gateway name (from cert-manager)                                     #
#      gateway_namespace --- Gateway namespace (from cert-manager)                                #
#      hostname          --- HTTPRoute hostname subdomain (e.g., "link" -> link.{domain})         #
#      max_expiration_days --- Maximum number of days content may be kept (retention cap)         #
#      name              --- Application name (used for resources)                                #
#      port              --- Container port                                                       #
#      preferred_gateway --- Preferred Gateway (e.g., "traefik")                                  #
#      resources         --- Resource requests and limits for the application                     #
#      retention_enabled --- Run the retention enforcer CronJob                                  #
#      retention_resources --- Resource requests and limits for the retention job                 #
#      retention_schedule --- Cron schedule for the retention enforcer                            #
#      retention_vacuum  --- VACUUM the database during retention runs                           #
#      storage_size      --- Volume size for the PicoShare database                                #
#    secrets             --- Secrets object (map of sensitive values)                             #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = false
}

variable "config" {
  description = "Application configuration"
  type = object({
    domain              = optional(string)
    env                 = optional(map(string))
    gateway_name        = optional(string)
    gateway_namespace   = optional(string)
    hostname            = optional(string)
    max_expiration_days = optional(number, 7)
    name                = optional(string, "picoshare")
    port                = optional(number, 4001)
    preferred_gateway   = optional(string)
    resources = optional(object({
      limits   = optional(map(string))
      requests = optional(map(string))
    }))
    retention_enabled = optional(bool, true)
    retention_resources = optional(object({
      limits   = optional(map(string))
      requests = optional(map(string))
    }))
    retention_schedule = optional(string, "0 */6 * * *")
    storage_size       = optional(string, "4Gi")
    retention_vacuum   = optional(bool, true)
  })
  default = {}
}

variable "secrets" {
  description = "Secrets object (map of sensitive values)"
  type        = map(string)
  default     = {}
  sensitive   = true
}
