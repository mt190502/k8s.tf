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
#  Private network for internal cluster communication (when enabled)                              #
## --------------------------------------------------------------------------------------------- ##
resource "hcloud_network" "private" {
  count    = var.config.private_network.enabled ? 1 : 0
  name     = "${var.config.cluster_name}-private"
  ip_range = var.config.private_network.cidr
}

resource "hcloud_network_subnet" "private" {
  count        = var.config.private_network.enabled ? 1 : 0
  network_id   = hcloud_network.private[0].id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = var.config.private_network.cidr
}

resource "hcloud_server_network" "private" {
  for_each  = var.config.private_network.enabled ? hcloud_server.nodes : {}
  server_id = each.value.id
  subnet_id = hcloud_network_subnet.private[0].id
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
      direction   = "in"
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
  server_type  = each.value.server_type
  location     = each.value.location
  image        = each.value.image_id
  labels       = { "role" : each.value.role }
  user_data    = var.deps.talos.machine_configurations[each.value.name]
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