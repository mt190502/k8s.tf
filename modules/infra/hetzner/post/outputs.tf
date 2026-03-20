## ============================================================================================= ##
#  modules/infra/hetzner/post/outputs.tf                                                          #
#                                                                                                 #
#  Outputs for the Hetzner post stage --- consumed by tailscale/post and cloudflare/post.         #
#                                                                                                 #
#    controlplane_nodes --- Controlplane nodes with metadata + public IPs                         #
#    nodes              --- All nodes with metadata + public IPs                                  #
## ============================================================================================= ##
locals {
  nodes_by_name = { for node in var.config.nodes : node.name => node }
}

output "controlplane_nodes" {
  description = "Map of controlplane nodes only"
  value = {
    for name, server in hcloud_server.nodes : name => {
      name         = server.name
      role         = local.nodes_by_name[name].role
      type         = local.nodes_by_name[name].type
      location     = local.nodes_by_name[name].location
      ipv4_address = server.ipv4_address
      ipv6_address = server.ipv6_address
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
      type         = local.nodes_by_name[name].type
      location     = local.nodes_by_name[name].location
      ipv4_address = server.ipv4_address
      ipv6_address = server.ipv6_address
      taints       = local.nodes_by_name[name].taints
    }
  }
}
