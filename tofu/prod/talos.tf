resource "talos_machine_secrets" "this" {
  talos_version = var.talos.version
}

data "talos_machine_configuration" "nodes" {
  for_each           = local.hetzner_nodes
  cluster_name       = var.cluster.name
  cluster_endpoint   = "https://${var.cluster.url.prefixes.api}.${var.cluster.url.main}:6443"
  machine_type       = each.value.role
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.cluster.version
  config_patches = [
    templatefile("templates/dualstack.tmpl", {}),
    templatefile("templates/longhorn.tmpl", {}),
    templatefile("templates/tailscale.tmpl", {
      TS_AUTHKEY  = var.tokens.tailscale.auth_key,
      TS_HOSTNAME = each.value.name
    }),
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for m in data.tailscale_device.masters : m.addresses[0]]
  nodes                = [for n in values(local.tailscale_nodes) : n.addresses[0]]
}

resource "talos_machine_bootstrap" "bootstrap" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.tailscale_device.masters[var.cluster.nodes.masters[0].name].addresses[0]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.tailscale_device.masters[var.cluster.nodes.masters[0].name].addresses[0]
  depends_on = [
    talos_machine_bootstrap.bootstrap,
    cloudflare_dns_record.masters_v4,
    cloudflare_dns_record.masters_v6,
    cloudflare_dns_record.lb
  ]
}
