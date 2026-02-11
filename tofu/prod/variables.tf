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
  })
  default = {
    version = "v1.12.2"
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
      main = string
      prefixes = object({
        api      = string
        external = string
        internal = string
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
        type        = string
        source_ips  = list(string)
      }))
    })
  })
  default = {
    name    = ""
    version = "v1.34.3"
    url = {
      main = ""
      prefixes = {
        api      = "k8s"
        external = "ext"
        internal = "int"
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