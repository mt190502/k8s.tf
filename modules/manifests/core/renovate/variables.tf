## ============================================================================================= ##
#  modules/manifests/core/renovate/variables.tf                                                   #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      active_deadline_seconds --- Hard limit for a single Renovate run (seconds)                 #
#      autodiscover      --- Discover repositories from the GitHub App installation               #
#      autodiscover_filter --- Autodiscover filter, e.g. "owner/*" or "owner/repo"                #
#      config_js_extra   --- Extra JavaScript appended to the generated config.js                 #
#      concurrency_policy --- CronJob concurrency policy (Forbid/Allow/Replace)                   #
#      env               --- Extra environment variables (map of key-value)                       #
#      log_level         --- Renovate log level                                                   #
#      name              --- Application name (used for resources)                                #
#      onboarding        --- Create an onboarding PR in repositories without a config             #
#      repositories      --- Explicit repository list (overrides autodiscover)                    #
#      require_config    --- Require a Renovate config file (required/optional/ignored)           #
#      resources         --- Resource requests and limits for the runner                          #
#      schedule          --- CronJob schedule (5-field cron expression)                           #
#      storage_class     --- Storage class for the Renovate cache volume                          #
#      storage_size      --- Volume size for the Renovate cache                                   #
#      timezone          --- CronJob time zone (requires Kubernetes >= 1.27)                      #
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
    active_deadline_seconds = optional(number, 3600)
    autodiscover            = optional(bool, true)
    autodiscover_filter     = optional(string)
    config_js_extra         = optional(string)
    concurrency_policy      = optional(string, "Forbid")
    env                     = optional(map(string))
    log_level               = optional(string, "info")
    name                    = optional(string, "renovate")
    onboarding              = optional(bool, true)
    repositories            = optional(list(string), [])
    require_config          = optional(string, "optional")
    resources = optional(object({
      limits   = optional(map(string))
      requests = optional(map(string))
    }))
    schedule      = optional(string, "0 * * * *")
    storage_class = optional(string)
    storage_size  = optional(string, "512Mi")
    timezone      = optional(string, "Europe/Istanbul")
  })
  default = {}
}

variable "secrets" {
  description = "Secrets object (map of sensitive values)"
  type        = map(string)
  default     = {}
  sensitive   = true
}
