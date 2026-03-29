## ============================================================================================= ##
#  modules/infra/talos/pre/main.tf                                                                #
#                                                                                                 #
#  Generates Talos machine secrets and renders per-node machine configs.                          #
#  Rendered configs are passed to hetzner/post (user_data) and talos/post (apply).                #
#                                                                                                 #
#    talos_machine_secrets.this             --- generates TLS credentials for the cluster         #
#    data.talos_machine_configuration.nodes --- renders machine config per node                   #
## ============================================================================================= ##
locals {
  private_network_cidr = try(var.rootvars.hetzner.private_network.cidr, "")
  cluster_cidrs = (
    try(var.rootvars.hetzner.private_network.enabled, false) && try(var.rootvars.tailscale.enabled, false)
    ? concat([local.private_network_cidr], ["100.64.0.0/10", "fd7a:115c:a1e0::/48"])
    : (try(var.rootvars.hetzner.private_network.enabled, false)
      ? [local.private_network_cidr]
      : (try(var.rootvars.tailscale.enabled, false)
        ? ["100.64.0.0/10", "fd7a:115c:a1e0::/48"]
        : []
      )
    )
  )
}

resource "talos_machine_secrets" "this" {
  count         = length(var.config.nodes) > 0 ? 1 : 0
  talos_version = var.versions.talos
}

data "talos_machine_configuration" "nodes" {
  for_each           = { for node in var.config.nodes : node.name => node }
  cluster_name       = var.config.cluster_name
  cluster_endpoint   = "https://${var.config.cluster_url.apiserver}:6443"
  machine_type       = each.value.role
  machine_secrets    = talos_machine_secrets.this[0].machine_secrets
  kubernetes_version = var.versions.kubernetes
  config_patches = concat(
    each.value.role == "controlplane" ? [
      templatefile("../templates/controlplane.tmpl", {
        ETCD_CIDRS = local.cluster_cidrs
      }),
      templatefile("../templates/cilium_postinstall_job.tmpl", {
        APISERVER_HOST    = var.config.kubeprism ? "127.0.0.1" : var.config.cluster_url.apiserver
        CILIUM_VERSION    = var.versions.cilium
        CLUSTER_DOMAIN    = var.config.cluster_url.dns
        DUALSTACK         = var.config.dualstack ? "true" : "false"
        OPERATOR_REPLICAS = max(1, length([for node in var.config.nodes : node if node.role == "controlplane"]))
        PREFERRED_GATEWAY = var.config.preferred_gateway
        SRV_PORT          = var.config.kubeprism ? "7445" : "6443"
      }),
    ] : [],
    [
      templatefile("../templates/machine.tmpl", {
        CERT_SANS            = values(var.config.cluster_url)
        KUBELET_NODEIP_CIDRS = local.cluster_cidrs
        TAILSCALE            = try(var.rootvars.tailscale.enabled, false) ? "true" : "false"
      }),
      templatefile("../templates/cni.tmpl", {
        DNS_DOMAIN    = var.config.cluster_url.dns
        POD_CIDRS     = concat([var.config.ipcfg.pod.ipv4], var.config.dualstack ? [var.config.ipcfg.pod.ipv6] : [])
        SERVICE_CIDRS = concat([var.config.ipcfg.service.ipv4], var.config.dualstack ? [var.config.ipcfg.service.ipv6] : [])
      }),
      templatefile("../templates/longhorn.tmpl", {}),
      templatefile("../templates/extras.tmpl", {}),
      templatefile("../templates/kubeprism.tmpl", {
        ENABLED = var.config.kubeprism
      }),
      templatefile("../templates/kubespan.tmpl", {
        ENABLED = var.config.kubespan
      }),
      try(var.rootvars.tailscale.enabled, false) ? templatefile("../templates/tailscale.tmpl", {
        TS_AUTHKEY  = var.secrets.auth_key
        TS_HOSTNAME = each.value.name
      }) : ""
    ]
  )
  depends_on = [
    talos_machine_secrets.this,
  ]
}