resource "talos_machine_secrets" "this" {
  talos_version = var.talos.version
}

data "talos_machine_configuration" "nodes" {
  for_each           = local.hetzner_nodes
  cluster_name       = var.cluster.name
  cluster_endpoint   = "https://${var.cluster.url.apiserver}:6443"
  machine_type       = each.value.role
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.cluster.version
  config_patches = concat(
    #~ Only control plane nodes
    each.value.role == "controlplane" ? [
      templatefile("templates/controlplane.tmpl", {
        ETCD_CIDRS = join("\n", [
          for ip in local.tailscale_ranges : "      - ${ip}"
        ])
      }),
      templatefile("templates/cilium_postinstall_job.tmpl", {
        CILIUM_VERSION = "1.19.1"
        DUALSTACK      = var.talos.options.dualstack ? "true" : "false"
        SRV_PORT       = var.talos.options.kubeprism ? 7445 : 6443
        CLUSTER_DOMAIN = var.cluster.url.dns
      })
    ] : [],

    #~ All nodes
    [
      templatefile("templates/machine.tmpl", {
        CERT_SANS = join("\n", [
          for san in values(var.cluster.url) : "    - ${san}"
        ])
        KUBELET_NODEIP_CIDRS = join("\n", [
          for ip in local.tailscale_ranges : "        - ${ip}"
        ])
      }),
      templatefile("templates/cni.tmpl", {
        DNS_DOMAIN = var.cluster.url.dns
        POD_CIDRS = join("\n", [
          "      - ${var.cluster.ipcfg.pod_cidr.ipv4}",
          var.talos.options.dualstack ? "      - ${var.cluster.ipcfg.pod_cidr.ipv6}" : ""
        ])
        SERVICE_CIDRS = join("\n", [
          "      - ${var.cluster.ipcfg.service_cidr.ipv4}",
          var.talos.options.dualstack ? "      - ${var.cluster.ipcfg.service_cidr.ipv6}" : ""
        ])
      }),
      templatefile("templates/longhorn.tmpl", {}),
      templatefile("templates/extras.tmpl", {}),
      templatefile("templates/tailscale.tmpl", {
        TS_AUTHKEY  = var.tokens.tailscale.auth_key,
        TS_HOSTNAME = each.value.name
      }),
    ]
  )
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.cluster.url.apiserver]
  nodes                = [for name in keys(local.tailscale_nodes) : local.tailscale_ipv4[name]]
}

resource "talos_machine_configuration_apply" "nodes" {
  for_each                    = local.hetzner_nodes
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.nodes[each.key].machine_configuration
  node                        = local.tailscale_ipv4[each.value.name]
  depends_on = [
    hcloud_server.nodes,
    data.tailscale_device.masters,
    data.tailscale_device.workers,
    talos_machine_secrets.this,
    data.talos_machine_configuration.nodes,
  ]
}

resource "talos_machine_bootstrap" "bootstrap" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.tailscale_ipv4[var.cluster.nodes.masters[0].name]
  depends_on = [
    talos_machine_secrets.this,
    talos_machine_configuration_apply.nodes,
    data.tailscale_device.masters,
    data.tailscale_device.workers,
    cloudflare_dns_record.lb,
    cloudflare_dns_record.lb_v6,
    cloudflare_dns_record.masters,
    cloudflare_dns_record.masters_v6,
    data.talos_machine_configuration.nodes
  ]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.tailscale_ipv4[var.cluster.nodes.masters[0].name]
  depends_on = [
    talos_machine_bootstrap.bootstrap,
    talos_machine_configuration_apply.nodes,
    cloudflare_dns_record.masters,
    cloudflare_dns_record.masters_v6,
    cloudflare_dns_record.lb
  ]
}
