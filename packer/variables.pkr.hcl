//////////////////////////////////////////////////
//
//// Global Variables
//
//////////////////////////////////////////////////
//~ Talos Configuration
variable "talos_version" {
  description = "Talos version to use for the cluster"
  type        = string
  default     = "v1.12.2"
}

variable "talos_image_id" {
  description = "Image ID for the Talos OS (override to node-specific image IDs)"
  type        = string
  default     = "077514df2c1b6436460bc60faabc976687b16193b8a1290fda4366c69024fec2"
}

#~ Hetzner Cloud Configuration
variable "hetzner_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "server_location" {
  description = "Hetzner Cloud location for the cluster"
  type        = string
  default     = "nbg1"
}

variable "server_types" {
  description = "Server types for master and worker nodes (override to node-specific types)"
  type        = map(string)
  default = {
    amd64 = "cx33"
    arm64 = "cax11"
  }
}