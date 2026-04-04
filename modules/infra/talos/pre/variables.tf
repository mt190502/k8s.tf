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
#      nodes          --- List of all nodes: name, role, arch, taints                             #
#    secrets          --- Sensitive configuration                                                 #
#      auth_key       --- Tailscale auth key injected into each node's machine config             #
#    versions         --- Version configuration                                                   #
#      cilium         --- Cilium chart version for the post-install job patch                     #
#      gateway_api    --- Kubernetes Gateway API version                                          #
#      kubernetes     --- Kubernetes version                                                      #
#      metrics-server --- Metrics Server version                                                  #
#      talos          --- Talos version (used when generating machine secrets)                    #
#    rootvars         --- Root configuration (hetzner.private_network.enabled, tailscale.enabled) #
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
      arch   = optional(string)
      taints = list(string)
    }))
    overwrite_dns     = bool
    preferred_gateway = string
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
    gateway_api = string
    kubernetes = string
    metrics_server = string
    talos      = string
  })
}

variable "rootvars" {
  description = "Root configuration from parent stack"
  type        = any
  default     = {}
}
