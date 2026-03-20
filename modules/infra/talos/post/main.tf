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
    for name in keys(var.nodes) :
    name => compact(concat(
      [lookup(var.tailscale_ipv4, name, null)],
      var.config.dualstack ? [lookup(var.tailscale_ipv6, name, null)] : [],
    ))
  }
}

## --------------------------------------------------------------------------------------------- ##
#  Renders talosconfig from cluster name, client creds, endpoint, and all node IPs.               #
## --------------------------------------------------------------------------------------------- ##
data "talos_client_configuration" "this" {
  cluster_name         = var.config.cluster_name
  client_configuration = var.machine_secrets.client_configuration
  endpoints            = [var.config.cluster_endpoint]
  nodes                = flatten(values(local.node_ips))
}

## --------------------------------------------------------------------------------------------- ##
#  Applies rendered machine config to each node via its Tailscale IPv4 address.                   #
## --------------------------------------------------------------------------------------------- ##
resource "talos_machine_configuration_apply" "nodes" {
  for_each                    = var.nodes
  client_configuration        = var.machine_secrets.client_configuration
  machine_configuration_input = lookup(var.machine_configurations, each.key, "")
  node                        = lookup(var.tailscale_ipv4, each.key, "")
}

## --------------------------------------------------------------------------------------------- ##
#  Bootstraps etcd on the first controlplane node; runs after all configs are applied.            #
## --------------------------------------------------------------------------------------------- ##
resource "talos_machine_bootstrap" "bootstrap" {
  client_configuration = var.machine_secrets.client_configuration
  node                 = lookup(var.tailscale_ipv4, var.config.first_controlplane, "")
  depends_on = [
    talos_machine_configuration_apply.nodes,
  ]
}

## --------------------------------------------------------------------------------------------- ##
#  Fetches kubeconfig from the first controlplane after bootstrap completes.                      #
## --------------------------------------------------------------------------------------------- ##
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = var.machine_secrets.client_configuration
  node                 = lookup(var.tailscale_ipv4, var.config.first_controlplane, "")
  depends_on = [
    talos_machine_bootstrap.bootstrap,
    talos_machine_configuration_apply.nodes,
  ]
}
