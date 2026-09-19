## ============================================================================================== ##
#  modules/manifests/core/kube-prometheus-stack/variables.tf                                       #
#                                                                                                  #
#    enabled                     --- Enable this module                                            #
#    config                      --- Configuration object                                          #
#      alertmanager_hostname     --- Alertmanager HTTPRoute hostname prefix                        #
#      basic_auth                --- Enable basic authentication for Grafana (only with Traefik)   #
#      domain                    --- Base domain for HTTPRoute hostname                            #
#      gateway_name              --- Gateway name (from cert-manager)                              #
#      gateway_namespace         --- Gateway namespace (from cert-manager)                         #
#      gotify_enabled            --- Enable Alertmanager -> Gotify webhook receivers               # 
#      gotify_bridge_endpoints   --- Map of bridge name -> webhook URL (e.g., {loki="http://..."}) #       
#      hostname                  --- HTTPRoute hostname subdomain (e.g., "app" -> app.{domain})    #
#      preferred_gateway         --- Preferred Gateway for basic auth (e.g., "traefik")            #
#      prometheus_retention      --- Maximum time to retain Prometheus metrics                     #
#      prometheus_hostname       --- Prometheus HTTPRoute hostname prefix                          #
#      prometheus_retention_size --- Maximum Prometheus TSDB block size                            #
#      prometheus_storage_class  --- StorageClass for the Prometheus TSDB PVC                      #
#      prometheus_storage_size   --- Prometheus TSDB PVC size                                      #
#      storage_size              --- Volume size for Grafana                                       #
## ============================================================================================== ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Application configuration"
  type = object({
    alertmanager_hostname     = optional(string, "alertmanager.srv")
    basic_auth                = optional(bool, false)
    domain                    = optional(string)
    gateway_name              = optional(string)
    gateway_namespace         = optional(string)
    gotify_enabled            = optional(bool, false)
    gotify_bridge_endpoints   = optional(map(string), {})
    hostname                  = optional(string)
    preferred_gateway         = optional(string, "cilium")
    prometheus_hostname       = optional(string, "prometheus.srv")
    prometheus_retention      = optional(string, "7d")
    prometheus_retention_size = optional(string, "6GB")
    prometheus_storage_size   = optional(string, "8Gi")
    storage_size              = optional(string, "1Gi")
  })
  default = {}
}

variable "secrets" {
  description = "Application secrets"
  type        = map(map(string))
  sensitive   = true
  default     = {}
}