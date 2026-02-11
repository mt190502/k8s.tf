terraform {
  required_providers {
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 5.15.0" }
    hetzner    = { source = "hetznercloud/hcloud", version = "~> 1.60.0" }
    libvirt    = { source = "dmacvicar/libvirt", version = "~> 0.9.1" }
    tailscale  = { source = "tailscale/tailscale", version = "~> 0.24.0" }
    talos      = { source = "siderolabs/talos", version = "~> 0.10.0" }
  }
}

provider "cloudflare" {
  api_token = var.tokens.cloudflare.token
}

provider "hcloud" {
  token = var.tokens.hetzner
}

provider "libvirt" {
  uri = var.libvirt_uri != "" ? var.libvirt_uri : "qemu:///system"
}

provider "tailscale" {
  oauth_client_id     = var.tokens.tailscale.client_id
  oauth_client_secret = var.tokens.tailscale.client_secret
  tailnet             = var.tokens.tailscale.tailnet
}

provider "talos" {
  # No special configuration required
}
