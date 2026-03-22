## ============================================================================================= ##
#  modules/infra/cloudflare/post/main.tf                                                          #
#                                                                                                 #
#  Creates all Cloudflare DNS records for the cluster.                                            #
#                                                                                                 #
#    lb         (A)     --- all nodes' public IPv4      -> cluster_url.main (proxied)             #
#    lb_v6      (AAAA)  --- all nodes' public IPv6      -> cluster_url.main (proxied)             #
#    masters    (A)     --- controlplane Tailscale IPv4 (or public IPv4 fallback) -> apiserver    #
#    masters_v6 (AAAA)  --- controlplane Tailscale IPv6 (or public IPv6 fallback) -> apiserver    #
#    wildcard   (CNAME) --- *.dns_domain                -> cluster_url.main (proxied)             #
## ============================================================================================= ##
provider "cloudflare" {
  api_token = var.secrets.api_token
}

resource "cloudflare_dns_record" "lb" {
  for_each = var.deps.nodes
  zone_id  = var.secrets.zone_id
  name     = var.config.cluster_url.main
  content  = each.value.ipv4_address
  comment  = each.value.name
  proxied  = true
  type     = "A"
  ttl      = 1
}

resource "cloudflare_dns_record" "lb_v6" {
  for_each = var.config.dualstack ? var.deps.nodes : {}
  zone_id  = var.secrets.zone_id
  name     = var.config.cluster_url.main
  content  = each.value.ipv6_address
  comment  = each.value.name
  proxied  = true
  type     = "AAAA"
  ttl      = 1
}

resource "cloudflare_dns_record" "masters" {
  for_each = {
    for name, node in var.deps.nodes : name => node
    if node.role == "controlplane"
  }
  zone_id = var.secrets.zone_id
  name    = var.config.cluster_url.apiserver
  content = lookup(var.deps.tailscale.ipv4_addresses, each.value.name, each.value.ipv4_address)
  comment = each.value.name
  type    = "A"
  ttl     = 60
}

resource "cloudflare_dns_record" "masters_v6" {
  for_each = var.config.dualstack ? {
    for name, node in var.deps.nodes : name => node
    if node.role == "controlplane"
  } : {}
  zone_id = var.secrets.zone_id
  name    = var.config.cluster_url.apiserver
  content = lookup(var.deps.tailscale.ipv6_addresses, each.value.name, each.value.ipv6_address)
  comment = each.value.name
  type    = "AAAA"
  ttl     = 60
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = var.secrets.zone_id
  name    = var.config.cluster_url.dns == "cluster.local" ? "*" : "*.${var.config.cluster_url.dns}"
  content = var.config.cluster_url.main
  comment = "Wildcard record for ${var.config.cluster_url.dns}"
  proxied = true
  type    = "CNAME"
  ttl     = 1
}