## ============================================================================================= ##
#  modules/infra/hetzner/post/outputs.tf                                                          #
#                                                                                                 #
#  Outputs for the Hetzner post stage --- consumed by tailscale/post and cloudflare/post.         #
#                                                                                                 #
#    controlplane_nodes --- Controlplane nodes with metadata + public IPs                         #
#    nodes              --- All nodes with metadata + public IPs                                  #
#    private_network    --- Private network details (when enabled)                                #
## ============================================================================================= ##
locals {
  nodes_by_name = { for node in var.config.nodes : node.name => node }
  private_ips = var.config.private_network.enabled ? {
    for name, sn in hcloud_server_network.private : name => sn.ip
  } : {}
}

output "controlplane_nodes" {
  description = "Map of controlplane nodes only"
  value = {
    for name, server in hcloud_server.nodes : name => {
      name         = server.name
      role         = local.nodes_by_name[name].role
      arch         = local.nodes_by_name[name].arch
      location     = local.nodes_by_name[name].location
      ipv4_address = server.ipv4_address
      ipv6_address = server.ipv6_address
      private_ip   = try(local.private_ips[name], null)
      taints       = local.nodes_by_name[name].taints
    }
    if local.nodes_by_name[name].role == "controlplane"
  }
}

output "nodes" {
  description = "Map of all nodes with their metadata and IP addresses"
  value = {
    for name, server in hcloud_server.nodes : name => {
      name         = server.name
      role         = local.nodes_by_name[name].role
      arch         = local.nodes_by_name[name].arch
      location     = local.nodes_by_name[name].location
      ipv4_address = server.ipv4_address
      ipv6_address = server.ipv6_address
      private_ip   = try(local.private_ips[name], null)
      taints       = local.nodes_by_name[name].taints
    }
  }
}

output "private_network" {
  description = "Private network configuration (when enabled)"
  value = var.config.private_network.enabled ? {
    id     = hcloud_network.private[0].id
    cidr   = var.config.private_network.cidr
    subnet = var.config.private_network.cidr
  } : null
}
