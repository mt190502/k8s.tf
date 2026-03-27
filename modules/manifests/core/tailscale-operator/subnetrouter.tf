## ============================================================================================= ##
#  modules/manifests/core/tailscale-operator/subnetrouter.tf                                      #
#                                                                                                 #
#  Deploys Tailscale Operator's Subnet Router feature, which allows exposing on-premises subnets  #
#  to the Tailscale network.                                                                      #
## ============================================================================================= ##
locals {
  subnet_router_name = "ts-pod-cidrs"
  subnet_router_manifest = yamlencode({
    apiVersion = "tailscale.com/v1alpha1"
    kind       = "Connector"
    metadata = {
      name      = local.subnet_router_name
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      hostname = "tailscale-kube-internal"
      subnetRouter = {
        advertiseRoutes = var.config.subnet_router_advertised_cidrs
      }
      tags = [
        "tag:k8s-pods"
      ]
    }
  })
}

data "external" "subnet_router_exists" {
  program = [
    "bash",
    "-c",
    "kubectl get connector ${local.subnet_router_name} -n ${kubernetes_namespace_v1.this.metadata[0].name} >/dev/null 2>&1 && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'",
  ]
}

resource "null_resource" "subnet_router" {
  triggers = {
    name         = local.subnet_router_name
    namespace    = kubernetes_namespace_v1.this.metadata[0].name
    manifest_sha = sha256(local.subnet_router_manifest)
    exists       = data.external.subnet_router_exists.result.exists
  }
  provisioner "local-exec" {
    command = "[ \"true\" = \"${self.triggers.exists}\" ] || kubectl apply -f - <<EOF\n${local.subnet_router_manifest}\nEOF"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "[ \"true\" = \"${self.triggers.exists}\" ] && kubectl delete connector ${self.triggers.name} -n ${self.triggers.namespace} --ignore-not-found=true || true"
  }
  depends_on = [helm_release.this]
}
