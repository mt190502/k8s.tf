## ============================================================================================= ##
#  modules/infra/hetzner/post/outputs.tf                                                          #
#                                                                                                 #
#  Outputs for the Hetzner post stage --- consumed by tailscale/post and cloudflare/post.         #
#                                                                                                 #
#    controlplane_nodes --- Controlplane nodes with metadata + public/private IPs                 #
#    nodes              --- All nodes with metadata + public/private IPs                          #
#    private_network    --- Private network details (id, cidr, subnet) when enabled               #
## ============================================================================================= ##
output "controlplane_nodes" {
  description = "Map of controlplane nodes only"
  value = {
    for name, srv in hcloud_server.nodes : name => {
      name         = srv.name
      role         = srv.labels["role"]
      arch         = var.config.nodes[index(var.config.nodes[*].name, name)].arch
      location     = srv.location
      ipv4_address = srv.ipv4_address
      ipv6_address = srv.ipv6_address
      private_ip   = var.config.private_network.enabled ? local.private_ips[name] : null
      taints       = var.config.nodes[index(var.config.nodes[*].name, name)].taints
    }
    if srv.labels["role"] == "controlplane"
  }
}

output "nodes" {
  description = "Map of all nodes with their metadata and IP addresses"
  value = {
    for name, srv in hcloud_server.nodes : name => {
      name         = srv.name
      role         = srv.labels["role"]
      arch         = var.config.nodes[index(var.config.nodes[*].name, name)].arch
      location     = srv.location
      ipv4_address = srv.ipv4_address
      ipv6_address = srv.ipv6_address
      private_ip   = var.config.private_network.enabled ? local.private_ips[name] : null
      taints       = var.config.nodes[index(var.config.nodes[*].name, name)].taints
    }
  }
}

output "private_network" {
  description = "Private network configuration (when enabled)"
  value = var.config.private_network.enabled && length(hcloud_network.private) > 0 ? {
    id     = hcloud_network.private[0].id
    cidr   = var.config.private_network.cidr
    subnet = var.config.private_network.cidr
  } : null
}