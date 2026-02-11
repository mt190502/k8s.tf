data "tailscale_device" "masters" {
  for_each = { for node in var.cluster.nodes.masters : node.name => node }
  hostname = each.value.name
  wait_for = "60s"
  depends_on = [
    hcloud_server.nodes
  ]
}

data "tailscale_device" "workers" {
  for_each = { for node in var.cluster.nodes.workers : node.name => node }
  hostname = each.value.name
  wait_for = "60s"
  depends_on = [
    hcloud_server.nodes
  ]
}

# resource "tailscale_device_tags" "nodes" {
#   #~ not required if tags are set in the provided client configuration
#   for_each  = local.tailscale_nodes
#   device_id = each.value.node_id
#   tags      = ["k8s-node", "servers"]
#   depends_on = [
#     data.tailscale_device.masters,
#     data.tailscale_device.workers
#   ]
# }