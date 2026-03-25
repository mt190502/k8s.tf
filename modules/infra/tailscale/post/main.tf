## ============================================================================================= ##
#  modules/infra/tailscale/post/main.tf                                                           #
#                                                                                                 #
#  Discovers Tailscale device IPs for all nodes after they join the tailnet.                      #
#  Nodes are created by hetzner/post; this stage waits for them to appear in the API.             #
#                                                                                                 #
#    locals.masters/worker/all  --- split nodes by role for parallel data source lookups          #
#    data.tailscale_device.*    --- waits for each device to appear, extracts IPs                 #
#    resource.null_resource     --- deletes devices from tailnet on destroy via REST API          #
## ============================================================================================= ##
locals {
  masters = { for name, node in var.deps.nodes : name => node if node.role == "controlplane" }
  workers = { for name, node in var.deps.nodes : name => node if node.role == "worker" }
  all = merge(
    { for name, dev in data.tailscale_device.masters : name => dev },
    { for name, dev in data.tailscale_device.workers : name => dev },
  )
}

provider "tailscale" {
  oauth_client_id     = var.secrets.client_id
  oauth_client_secret = var.secrets.client_secret
  tailnet             = var.secrets.tailnet
}

data "tailscale_device" "masters" {
  for_each = local.masters
  hostname = each.value.name
  wait_for = "60s"
}

data "tailscale_device" "workers" {
  for_each = local.workers
  hostname = each.value.name
  wait_for = "60s"
}

## --------------------------------------------------------------------------------------------- ##
#  Removes each device from the tailnet on destroy via the Tailscale REST API.                    #
#  Hetzner destroy does not auto-deregister devices; OAuth creds are required for the call.       #
#  `|| true` prevents destroy failure if the device is already gone.                              #
## --------------------------------------------------------------------------------------------- ##
resource "null_resource" "destroy_tailscale" {
  for_each = local.all
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
    device_id           = each.value.id
    oauth_client_id     = var.secrets.client_id
    oauth_client_secret = var.secrets.client_secret
  }
}