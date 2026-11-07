## ============================================================================================= ##
#  modules/manifests/core/tailscale-operator/subnetrouter.tf                                      #
#                                                                                                 #
#  Deploys Tailscale Operator's Subnet Router feature, which allows exposing on-premises subnets  #
#  to the Tailscale network.                                                                      #
#  Uses null_resource + kubectl because the kubernetes provider does not support CRDs well.       #
#  Apply stamps srv.mtaha.dev/tf-owner on the live object; destroy deletes it only when the       #
#  annotation still matches this instance, so a replacement never gaps the object.                #
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

resource "null_resource" "subnet_router" {
  triggers = {
    name         = local.subnet_router_name
    namespace    = kubernetes_namespace_v1.this.metadata[0].name
    manifest_sha = sha256(local.subnet_router_manifest)
  }
  lifecycle {
    create_before_destroy = true
  }
  provisioner "local-exec" {
    command = "{ kubectl apply -f - <<EOF\n${local.subnet_router_manifest}\nEOF\n} && kubectl annotate --overwrite connector ${self.triggers.name} -n ${self.triggers.namespace} srv.mtaha.dev/tf-owner=${self.id}"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "owner=$(kubectl get connector ${self.triggers.name} -n ${self.triggers.namespace} -o jsonpath='{.metadata.annotations.srv\\.mtaha\\.dev/tf-owner}' 2>/dev/null || true); [ \"$${owner}\" = \"${self.id}\" ] && kubectl delete connector ${self.triggers.name} -n ${self.triggers.namespace} --ignore-not-found=true || true"
  }
  depends_on = [helm_release.this]
}
