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

resource "null_resource" "destroy_tailscale" {
  for_each = {
    for k, d in local.tailscale_nodes : k => d.id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      TOKEN=$(curl -sX POST "https://api.tailscale.com/api/v2/oauth/token" \
        -d "client_id=${self.triggers.oauth_client_id}" \
        -d "client_secret=${self.triggers.oauth_client_secret}" \
        -d "grant_type=client_credentials" | jq -r '.access_token')
      curl -sX DELETE "https://api.tailscale.com/api/v2/device/${self.triggers.device_id}" \
        -H "Authorization: Bearer $TOKEN" || true
    EOT
  }

  triggers = {
    device_id           = each.value
    oauth_client_id     = var.tokens.tailscale.client_id
    oauth_client_secret = var.tokens.tailscale.client_secret
  }
}