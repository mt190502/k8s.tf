locals {
  hetzner_nodes = merge(
    { for node in var.cluster.nodes.masters : node.name => merge(node, { role = "controlplane" }) },
    { for node in var.cluster.nodes.workers : node.name => merge(node, { role = "worker" }) },
  )
  tailscale_nodes = merge(
    { for name, node in data.tailscale_device.masters : name => node },
    { for name, node in data.tailscale_device.workers : name => node },
  )
  tailscale_ipv4 = {
    for name, dev in local.tailscale_nodes :
    name => try(
      one([
        for a in dev.addresses : a
        if can(cidrcontains("100.64.0.0/10", a)) && cidrcontains("100.64.0.0/10", a)
      ]),
      one([
        for a in dev.addresses : a
        if can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", a))
      ]),
      null,
    )
  }
  tailscale_ipv6 = var.talos.options.dualstack ? {
    for name, dev in local.tailscale_nodes :
    name => try(
      one([
        for a in dev.addresses : a
        if can(cidrcontains("fd7a:115c:a1e0::/48", a)) && cidrcontains("fd7a:115c:a1e0::/48", a)
      ]),
      one([
        for a in dev.addresses : a
        if strcontains(a, ":")
      ]),
      null,
    )
  } : {}
  tailscale_ranges = concat(
    ["100.64.0.0/10"],
    var.talos.options.dualstack ? ["fd7a:115c:a1e0::/48"] : []
  )
}
