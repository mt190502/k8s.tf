## ============================================================================================= ##
#  modules/infra/talos/post/main.tf                                                               #
#                                                                                                 #
#  Applies machine configs to nodes, bootstraps etcd, retrieves kubeconfig.                       #
#                                                                                                 #
#    data.talos_client_configuration.this     --- renders talosconfig (endpoint + nodes)          #
#    talos_machine_configuration_apply.nodes  --- pushes config to each node                      #
#    talos_machine_bootstrap.bootstrap        --- bootstraps etcd on first controlplane           #
#    talos_cluster_kubeconfig.this            --- fetches kubeconfig after cluster is up          #
## ============================================================================================= ##
## --------------------------------------------------------------------------------------------- ##
#  Renders talosconfig from cluster name, client creds, endpoint, and all node IPs.               #
## --------------------------------------------------------------------------------------------- ##
data "talos_client_configuration" "this" {
  cluster_name         = var.config.cluster_name
  client_configuration = var.deps.talos.machine_secrets.client_configuration
  endpoints            = [var.config.cluster_endpoint]
  nodes                = values(var.deps.node_ips)
}

## --------------------------------------------------------------------------------------------- ##
#  Applies rendered machine config to each node.                                                   #
## --------------------------------------------------------------------------------------------- ##
resource "talos_machine_configuration_apply" "nodes" {
  for_each                    = var.deps.node_ips
  client_configuration        = var.deps.talos.machine_secrets.client_configuration
  machine_configuration_input = var.deps.talos.machine_configurations[each.key]
  node                        = each.value
}

## --------------------------------------------------------------------------------------------- ##
#  Bootstraps etcd on the first controlplane node; runs after all configs are applied.            #
## --------------------------------------------------------------------------------------------- ##
resource "talos_machine_bootstrap" "bootstrap" {
  client_configuration = var.deps.talos.machine_secrets.client_configuration
  node                 = try(var.deps.node_ips[var.config.first_controlplane], values(var.deps.node_ips)[0])
  depends_on = [
    talos_machine_configuration_apply.nodes,
  ]
}

## --------------------------------------------------------------------------------------------- ##
#  Fetches kubeconfig from the first controlplane after bootstrap completes.                      #
## --------------------------------------------------------------------------------------------- ##
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = var.deps.talos.machine_secrets.client_configuration
  node                 = try(var.deps.node_ips[var.config.first_controlplane], values(var.deps.node_ips)[0])
  depends_on = [
    talos_machine_bootstrap.bootstrap,
    talos_machine_configuration_apply.nodes,
  ]
}
