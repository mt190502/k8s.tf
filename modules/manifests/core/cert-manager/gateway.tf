## ============================================================================================= ##
#  modules/manifests/core/cert-manager/gateway.tf                                                 #
#                                                                                                 #
#  Creates the shared Cilium Gateway (HTTPS :443, *.dns_domain) in cert-manager namespace.        #
#  TLS is terminated with the wildcard certificate from wildcard.tf.                              #
#  Uses null_resource + kubectl because the kubernetes provider does not support CRDs well.       #
#  Refs: https://github.com/hashicorp/terraform-provider-kubernetes/issues/2673                   #
#        https://github.com/hashicorp/terraform-provider-kubernetes/issues/2777                   #
## ============================================================================================= ##
locals {
  gateway_name = "gateway"
  gateway = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = local.gateway_name
      namespace = kubernetes_namespace_v1.this.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = local.clusterissuer_name
      }
    }
    spec = {
      gatewayClassName = "cilium"
      listeners = [
        {
          name     = "websecure"
          hostname = "*.${var.config.dns_domain}"
          port     = 443
          protocol = "HTTPS"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                name      = local.certificate_name
                namespace = kubernetes_namespace_v1.this.metadata[0].name
              }
            ]
          }
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        }
      ]
    }
  })
}

data "external" "gateway_exists" {
  program = [
    "bash",
    "-c",
    "kubectl get gateway ${local.gateway_name} -n ${kubernetes_namespace_v1.this.metadata[0].name} >/dev/null 2>&1 && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'",
  ]
}

resource "null_resource" "gateway" {
  triggers = {
    name         = local.gateway_name
    namespace    = kubernetes_namespace_v1.this.metadata[0].name
    manifest_sha = sha256(local.gateway)
    exists       = data.external.gateway_exists.result.exists
  }

  provisioner "local-exec" {
    command = "[ \"true\" = \"${self.triggers.exists}\" ] || kubectl apply -f - <<EOF\n${local.gateway}\nEOF"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "[ \"true\" = \"${self.triggers.exists}\" ] && kubectl delete gateway ${self.triggers.name} -n ${self.triggers.namespace} --ignore-not-found=true || true"
  }

  depends_on = [
    null_resource.clusterissuer,
    null_resource.certificate,
  ]
}
