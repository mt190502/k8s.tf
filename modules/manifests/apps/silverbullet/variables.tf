## ============================================================================================= ##
#  modules/manifests/apps/silverbullet/variables.tf                                               #
#                                                                                                 #
#    enabled             --- Enable this module                                                   #
#    config              --- Configuration object                                                 #
#      basic_auth        --- Enable basic authentication at the Gateway (recommended)             #
#      domain            --- Base domain for HTTPRoute hostname                                   #
#      env               --- Environment variables (map of key-value, e.g. TZ, SB_USER)           #
#      gateway_name      --- Gateway name (from cert-manager)                                     #
#      gateway_namespace --- Gateway namespace (from cert-manager)                                #
#      hostname          --- HTTPRoute hostname subdomain (e.g., "md" -> md.{domain})             #
#      image             --- Pinned SilverBullet image                                            #
#      mcp               --- Optional in-pod MCP sidecar (/.fs bridge, tailnet-only port)         #
#      name              --- Application name (used for resources)                                #
#      port              --- HTTP port SilverBullet listens on                                    #
#      preferred_gateway --- Preferred Gateway for basic auth (e.g., "traefik")                   #
#      resources         --- Resource requests and limits for the application                     #
#        limits          --- Resource limits for the application (cpu, memory)                    #
#        requests        --- Resource requests for the application (cpu, memory)                  #
#      storage_size      --- Markdown notes volume size (mounted at /space)                       #
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
    basic_auth        = optional(bool, true)
    domain            = optional(string)
    env               = optional(map(string))
    gateway_name      = optional(string)
    gateway_namespace = optional(string)
    hostname          = optional(string)
    image             = optional(string, "ghcr.io/silverbulletmd/silverbullet:2.11.1")
    mcp = optional(object({
      enabled      = optional(bool, false)
      public       = optional(bool, false)
      instructions = optional(string, "")
      resources = optional(object({
        requests = optional(map(string), { cpu = "25m", memory = "64Mi" })
        limits   = optional(map(string), { cpu = "200m", memory = "256Mi" })
      }), {})
    }), {})
    name              = optional(string, "silverbullet")
    port              = optional(number, 3000)
    preferred_gateway = optional(string, "cilium")
    resources = optional(object({
      limits   = optional(map(string))
      requests = optional(map(string))
    }))
    storage_size = optional(string, "2Gi")
  })
  default = {}
}

variable "secrets" {
  description = "Application secrets"
  type        = map(map(string))
  sensitive   = true
  default     = {}
}
