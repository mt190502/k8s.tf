## ============================================================================================= ##
#  modules/infra/talos/post/main.tf                                                               #
#                                                                                                 #
#  Applies machine configs to nodes, bootstraps etcd, retrieves kubeconfig.                       #
#                                                                                                 #
#    data.talos_client_configuration.this     --- renders talosconfig (endpoint + nodes)          #
#    talos_machine_configuration_apply.nodes  --- pushes config to each node via Tailscale        #
#    talos_machine_bootstrap.bootstrap        --- bootstraps etcd on first controlplane           #
#    talos_cluster_kubeconfig.this            --- fetches kubeconfig after cluster is up          #
## ============================================================================================= ##
locals {
  node_ips = {
    for name in keys(var.deps.nodes) :
    name => compact(concat(
      [lookup(var.deps.tailscale.ipv4_addresses, name, null)],
      # var.config.dualstack ? [lookup(var.deps.tailscale.ipv6_addresses, name, null)] : [],
    ))
  }
}

## --------------------------------------------------------------------------------------------- ##
#  Renders talosconfig from cluster name, client creds, endpoint, and all node IPs.               #
## --------------------------------------------------------------------------------------------- ##
data "talos_client_configuration" "this" {
  cluster_name         = var.config.cluster_name
  client_configuration = var.deps.talos.machine_secrets.client_configuration
  endpoints            = [var.config.cluster_endpoint]
  nodes                = flatten(values(local.node_ips))
}

## --------------------------------------------------------------------------------------------- ##
#  Applies rendered machine config to each node via its Tailscale IPv4 address.                   #
## --------------------------------------------------------------------------------------------- ##
resource "talos_machine_configuration_apply" "nodes" {
  for_each                    = var.deps.nodes
  client_configuration        = var.deps.talos.machine_secrets.client_configuration
  machine_configuration_input = lookup(var.deps.talos.machine_configurations, each.key, "")
  node                        = lookup(var.deps.tailscale.ipv4_addresses, each.key, "")
}

## --------------------------------------------------------------------------------------------- ##
#  Bootstraps etcd on the first controlplane node; runs after all configs are applied.            #
## --------------------------------------------------------------------------------------------- ##
resource "talos_machine_bootstrap" "bootstrap" {
  client_configuration = var.deps.talos.machine_secrets.client_configuration
  node                 = lookup(var.deps.tailscale.ipv4_addresses, var.config.first_controlplane, "")
  depends_on = [
    talos_machine_configuration_apply.nodes,
  ]
}

## --------------------------------------------------------------------------------------------- ##
#  Fetches kubeconfig from the first controlplane after bootstrap completes.                      #
## --------------------------------------------------------------------------------------------- ##
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = var.deps.talos.machine_secrets.client_configuration
  node                 = lookup(var.deps.tailscale.ipv4_addresses, var.config.first_controlplane, "")
  depends_on = [
    talos_machine_bootstrap.bootstrap,
    talos_machine_configuration_apply.nodes,
  ]
}
