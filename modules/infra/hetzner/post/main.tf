## ============================================================================================= ##
#  modules/infra/hetzner/post/main.tf                                                             #
#                                                                                                 #
#  Creates Hetzner Cloud servers for all cluster nodes, and a firewall if enabled.                #
#                                                                                                 #
#    hcloud_firewall.fw  --- single firewall applied to all nodes (when enabled)                  #
#    hcloud_server.nodes --- one server per node; user_data used only on first boot               #
## ============================================================================================= ##
provider "hcloud" {
  token = var.secrets.api_token
}

## --------------------------------------------------------------------------------------------- ##
#  Single firewall applied to all nodes when enabled; rules sourced from var.firewall.rules       #
## --------------------------------------------------------------------------------------------- ##
resource "hcloud_firewall" "fw" {
  count = var.config.firewall.enabled ? 1 : 0
  name  = "${var.config.cluster_name}-firewall"
  dynamic "rule" {
    for_each = var.config.firewall.rules
    content {
      description = rule.value.description
      protocol    = rule.value.protocol
      port        = rule.value.port
      direction   = rule.value.direction
      source_ips  = rule.value.source_ips
    }
  }
}

## --------------------------------------------------------------------------------------------- ##
#  One server per node; user_data (machine config) is only consumed on first boot.                #
#  image and user_data are ignored after creation to prevent unintended replacements.             #
## --------------------------------------------------------------------------------------------- ##
resource "hcloud_server" "nodes" {
  for_each     = { for node in var.config.nodes : node.name => node }
  name         = each.value.name
  server_type  = var.config.image_ids[each.value.type].code
  location     = each.value.location
  image        = var.config.image_ids[each.value.type].id
  labels       = { "role" : each.value.role }
  user_data    = var.machine_configurations[each.value.name]
  firewall_ids = var.config.firewall.enabled ? [hcloud_firewall.fw[0].id] : []
  public_net {
    ipv4_enabled = true
    ipv6_enabled = var.config.dualstack
  }
  lifecycle {
    ignore_changes = [image, user_data]
  }
  depends_on = [hcloud_firewall.fw]
}