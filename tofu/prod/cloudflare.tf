resource "cloudflare_dns_record" "masters" {
  for_each = {
    for node in values(local.hetzner_nodes) : node.name => node
    if node.role == "controlplane"
  }
  zone_id = var.tokens.cloudflare.zone_id
  name    = var.cluster.url.apiserver
  content = local.tailscale_ipv4[each.value.name]
  comment = each.value.name
  type    = "A"
  ttl     = 60
}

resource "cloudflare_dns_record" "masters_v6" {
  for_each = var.talos.options.dualstack ? {
    for node in values(local.hetzner_nodes) : node.name => node
    if node.role == "controlplane"
  } : {}
  zone_id = var.tokens.cloudflare.zone_id
  name    = var.cluster.url.apiserver
  content = local.tailscale_ipv6[each.value.name]
  comment = each.value.name
  type    = "AAAA"
  ttl     = 60
}

resource "cloudflare_dns_record" "lb" {
  for_each = local.hetzner_nodes
  zone_id  = var.tokens.cloudflare.zone_id
  name     = var.cluster.url.main
  content  = hcloud_server.nodes[each.value.name].ipv4_address
  comment  = each.value.name
  proxied  = true
  type     = "A"
  ttl      = 1
}

resource "cloudflare_dns_record" "lb_v6" {
  for_each = var.talos.options.dualstack ? local.hetzner_nodes : {}
  zone_id  = var.tokens.cloudflare.zone_id
  name     = var.cluster.url.main
  content  = hcloud_server.nodes[each.value.name].ipv6_address
  comment  = each.value.name
  proxied  = true
  type     = "AAAA"
  ttl      = 1
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.tokens.cloudflare.zone_id
  name    = "*.${var.cluster.url.dns}"
  content = var.cluster.url.main
  comment = "Wildcard record for ${var.cluster.url.dns}"
  proxied = true
  type    = "CNAME"
  ttl     = 1
}