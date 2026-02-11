resource "hcloud_server" "nodes" {
  for_each     = local.hetzner_nodes
  name         = each.value.name
  server_type  = var.talos.images[each.value.type].code
  location     = each.value.location
  image        = var.talos.images[each.value.type].id
  labels       = { "role" : each.value.role }
  user_data    = data.talos_machine_configuration.nodes[each.key].machine_configuration
  firewall_ids = var.cluster.firewall != null ? [hcloud_firewall.fw[0].id] : []

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  lifecycle {
    ignore_changes = [image]
  }

  depends_on = [
    hcloud_firewall.fw,
  ]
}

resource "hcloud_firewall" "fw" {
  count = var.cluster.firewall != null ? 1 : 0
  name  = "${var.cluster.name}-firewall"
  dynamic "rule" {
    for_each = {
      for rule in var.cluster.firewall.rules : rule.short_name => rule
      if rule.type == "both" || rule.type == "external"
    }
    content {
      description = rule.value.description
      protocol    = rule.value.protocol
      port        = rule.value.port
      direction   = rule.value.direction
      source_ips  = rule.value.source_ips
    }
  }
}
