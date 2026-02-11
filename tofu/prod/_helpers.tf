locals {
  cluster_fqdn = {
    api      = "${var.cluster.url.prefixes.api}.${var.cluster.url.main}"
    external = "${var.cluster.url.prefixes.external}.${var.cluster.url.main}"
    internal = "${var.cluster.url.prefixes.internal}.${var.cluster.url.main}"
  }
  hetzner_nodes = merge(
    { for node in var.cluster.nodes.masters : node.name => merge(node, { role = "controlplane" }) },
    { for node in var.cluster.nodes.workers : node.name => merge(node, { role = "worker" }) },
  )
  tailscale_nodes = merge(
    { for node in data.tailscale_device.masters : node.hostname => node },
    { for node in data.tailscale_device.workers : node.hostname => node },
  )
}
