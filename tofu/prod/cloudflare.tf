resource "cloudflare_dns_record" "masters_v4" {
  for_each = {
    for node in values(local.hetzner_nodes) : node.name => node
    if node.role == "controlplane"
  }
  zone_id = var.tokens.cloudflare.zone_id
  name    = local.cluster_fqdn.api
  content = local.tailscale_nodes[each.value.name].addresses[0]
  comment = each.value.name
  type    = "A"
  ttl     = 3600
}

resource "cloudflare_dns_record" "masters_v6" {
  for_each = {
    for node in values(local.hetzner_nodes) : node.name => node
    if node.role == "controlplane"
  }
  zone_id = var.tokens.cloudflare.zone_id
  name    = local.cluster_fqdn.api
  content = local.tailscale_nodes[each.value.name].addresses[1]
  comment = each.value.name
  type    = "AAAA"
  ttl     = 3600
}

resource "cloudflare_dns_record" "lb" {
  for_each = local.hetzner_nodes
  zone_id  = var.tokens.cloudflare.zone_id
  name     = local.cluster_fqdn.external
  content  = local.tailscale_nodes[each.value.name].addresses[0]
  comment  = each.value.name
  type     = "A"
  ttl      = 3600
}