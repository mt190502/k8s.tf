## ============================================================================================= ##
#  modules/manifests/core/cert-manager/wildcard.tf                                                #
#                                                                                                 #
#  Issues a wildcard Certificate for *.dns_domain via the ClusterIssuer in issuer.tf.             #
#  The resulting Secret is annotated for Reflector to sync into configured namespaces.            #
#  Uses null_resource + kubectl because the kubernetes provider does not support CRDs well.       #
#  Refs: https://github.com/hashicorp/terraform-provider-kubernetes/issues/2673                   #
#        https://github.com/hashicorp/terraform-provider-kubernetes/issues/2777                   #
## ============================================================================================= ##
locals {
  certificate_name      = "wildcard-${var.config.dns_domain}-tls"
  reflection_namespaces = join(",", var.config.wildcard_reflection_namespaces)
  certificate = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = local.certificate_name
      namespace = kubernetes_namespace_v1.this.metadata[0].name
    }
    spec = {
      secretName = local.certificate_name
      secretTemplate = {
        annotations = {
          "reflector.v1.k8s.emberstack.com/reflection-allowed"            = "true"
          "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces" = local.reflection_namespaces
          "reflector.v1.k8s.emberstack.com/reflection-auto-enabled"       = "true"
          "reflector.v1.k8s.emberstack.com/reflection-auto-namespaces"    = local.reflection_namespaces
        }
      }
      dnsNames = [
        var.config.dns_domain,
        "*.${var.config.dns_domain}",
      ]
      issuerRef = {
        name = local.clusterissuer_name
        kind = "ClusterIssuer"
      }
    }
  })
}

data "external" "certificate_exists" {
  program = [
    "bash",
    "-c",
    "kubectl get certificate ${local.certificate_name} -n ${kubernetes_namespace_v1.this.metadata[0].name} >/dev/null 2>&1 && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'",
  ]
}

resource "null_resource" "certificate" {
  triggers = {
    name         = local.certificate_name
    namespace    = kubernetes_namespace_v1.this.metadata[0].name
    manifest_sha = sha256(local.certificate)
    exists       = data.external.certificate_exists.result.exists
  }
  provisioner "local-exec" {
    command = "[ \"true\" = \"${self.triggers.exists}\" ] || kubectl apply -f - <<EOF\n${local.certificate}\nEOF"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "[ \"true\" = \"${self.triggers.exists}\" ] && kubectl delete certificate ${self.triggers.name} -n ${self.triggers.namespace} --ignore-not-found=true || true"
  }
  depends_on = [null_resource.clusterissuer]
}
