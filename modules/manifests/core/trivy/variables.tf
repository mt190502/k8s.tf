## ============================================================================================= ##
#  modules/manifests/core/trivy/variables.tf                                                      #
#                                                                                                 #
#    enabled                       --- Enable this module                                         #
#    config                        --- Configuration object                                       #
#      built_in_trivy_server       --- Run the built-in trivy server (ClientServer scan mode)     #
#      severity                    --- Comma separated severities to report                       #
#      ignore_unfixed              --- Report only vulnerabilities with an available fix          #
#      scan_jobs_concurrent_limit  --- Maximum number of concurrent scan jobs                     #
#      scan_report_ttl             --- How long vulnerability reports are kept before rescanning  #
#      exclude_namespaces          --- Namespaces that are not scanned                            #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = false
}

variable "config" {
  description = "Trivy configuration"
  type = object({
    built_in_trivy_server      = optional(bool, true)
    severity                   = optional(string, "CRITICAL,HIGH")
    ignore_unfixed             = optional(bool, true)
    scan_jobs_concurrent_limit = optional(number, 3)
    scan_report_ttl            = optional(string, "168h")
    exclude_namespaces         = optional(list(string), ["kube-system", "trivy-system"])
  })
}
