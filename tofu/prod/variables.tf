//////////////////////////////////////////////////
//
//// Provider Configuration
//
//////////////////////////////////////////////////
variable "talos" {
  description = "Talos configuration for the cluster"
  type = object({
    version = string
    images = object({
      amd64 = object({
        id   = string
        code = string
      })
      arm64 = object({
        id   = string
        code = string
      })
    })
    options = object({
      dualstack = bool
      kubespan  = bool
      kubeprism = bool
    })
  })
  default = {
    version = "v1.12.4"
    images = {
      amd64 = {
        id   = ""
        code = ""
      }
      arm64 = {
        id   = ""
        code = ""
      }
    }
    options = {
      dualstack = true
      kubespan  = true
      kubeprism = true
    }
  }

  validation {
    condition = (
      (var.talos.images.amd64.id != "" && var.talos.images.arm64.id != "") ||
      (var.talos.images.amd64.id == "" && var.talos.images.arm64.id == "")
    )
    error_message = "Both AMD64 and ARM64 image IDs must be provided or both must be empty."
  }
}

variable "tokens" {
  description = "API tokens for various providers"
  type = object({
    cloudflare = object({
      zone_id = string
      token   = string
    })
    hetzner = string
    tailscale = object({
      auth_key      = string
      client_id     = string
      client_secret = string
      tailnet       = string
    })
  })
  sensitive = true
}


//////////////////////////////////////////////////
//
//// Cluster Configuration
//
/////////////////////////////////////////////////
variable "cluster" {
  description = "Configuration for the Kubernetes cluster"
  type = object({
    name    = string
    version = string
    url = object({
      dns       = string
      main      = string
      apiserver = string
    })
    ipcfg = object({
      pod_cidr = object({
        ipv4 = string
        ipv6 = string
      })
      service_cidr = object({
        ipv4 = string
        ipv6 = string
      })
    })
    nodes = object({
      masters = list(object({
        name     = string
        type     = string
        location = string
        taints   = list(string)
      }))
      workers = list(object({
        name     = string
        type     = string
        location = string
        taints   = list(string)
      }))
    })
    firewall = object({
      enabled = bool
      rules = list(object({
        short_name  = string
        description = string
        protocol    = string
        direction   = string
        port        = string
        source_ips  = list(string)
      }))
    })
  })
  default = {
    name    = ""
    version = "v1.35.1"
    url = {
      dns       = ""
      main      = ""
      apiserver = ""
    }
    ipcfg = {
      pod_cidr = {
        ipv4 = "10.244.0.0/16"
        ipv6 = "2001:db8:42:0::/56"
      }
      service_cidr = {
        ipv4 = "10.96.0.0/12"
        ipv6 = "2001:db8:42:1::/112"
      }
    }
    nodes = {
      masters = []
      workers = []
    }
    firewall = {
      enabled = false
      rules   = []
    }
  }
}