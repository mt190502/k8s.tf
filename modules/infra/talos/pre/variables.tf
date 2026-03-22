## ============================================================================================= ##
#  modules/infra/talos/pre/variables.tf                                                           #
#                                                                                                 #
#  Inputs for the Talos pre stage --- generates machine secrets and renders per-node configs.     #
#                                                                                                 #
#    enabled          --- Enable this module                                                      #
#    config           --- Configuration object                                                    #
#      ipcfg          --- Pod and service CIDRs (ipv4 + ipv6 each)                                #
#      cluster_name   --- Cluster name                                                            #
#      cluster_url    --- Cluster FQDNs: dns, main, apiserver                                     #
#      dualstack      --- Enable dual-stack IPv4/IPv6                                             #
#      kubeprism      --- Enable KubePrism (local apiserver proxy on port 7445)                   #
#      kubespan       --- Enable KubeSpan (WireGuard overlay between nodes)                       #
#      nodes          --- List of all nodes: name, role, taints                                   #
#    secrets          --- Sensitive configuration                                                 #
#      auth_key       --- Tailscale auth key injected into each node's machine config             #
#    versions         --- Version configuration                                                   #
#      cilium         --- Cilium chart version for the post-install job patch                     #
#      kubernetes     --- Kubernetes version                                                      #
#      talos          --- Talos version (used when generating machine secrets)                    #
## ============================================================================================= ##
variable "enabled" {
  description = "Enable this module"
  type        = bool
  default     = true
}

variable "config" {
  description = "Talos pre-stage configuration"
  type = object({
    ipcfg = object({
      pod = object({
        ipv4 = string
        ipv6 = string
      })
      service = object({
        ipv4 = string
        ipv6 = string
      })
    })
    cluster_name = string
    cluster_url = object({
      dns       = string
      main      = string
      apiserver = string
    })
    dualstack = bool
    kubeprism = bool
    kubespan  = bool
    nodes = list(object({
      name   = string
      role   = string
      taints = list(string)
    }))
  })
}

variable "secrets" {
  description = "Talos pre-stage secrets"
  type = object({
    auth_key = string
  })
  sensitive = true
}

variable "versions" {
  description = "Talos pre-stage version configuration"
  type = object({
    cilium     = string
    kubernetes = string
    talos      = string
  })
}

variable "rootvars" {
  description = "Root configuration from parent stack"
  type        = any
  default     = {}
}