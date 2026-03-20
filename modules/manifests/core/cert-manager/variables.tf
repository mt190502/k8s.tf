## ============================================================================================= ##
#  modules/manifests/core/cert-manager/variables.tf                                               #
#                                                                                                 #
#    enabled                          --- Enable this module                                      #
#    config                           --- Configuration object                                    #
#      acme_email                     --- Email for Let's Encrypt account registration            #
#      dns_domain                     --- Base domain for the wildcard certificate                #
#      wildcard_reflection_namespaces --- Namespaces Reflector will sync the wildcard secret to   #
#    secrets                          --- Sensitive configuration                                 #
#      api_token                      --- Cloudflare API token for DNS01 ACME challenge           #
#    versions                         --- Version configuration                                   #
#      chart                          --- cert-manager Helm chart version                         #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "cert-manager configuration"
  type = object({
    acme_email                     = string
    dns_domain                     = string
    wildcard_reflection_namespaces = list(string)
  })
}

variable "secrets" {
  description = "cert-manager secrets"
  type = object({
    api_token = string
  })
  sensitive = true
}

variable "versions" {
  description = "cert-manager version configuration"
  type = object({
    chart = string
  })
}