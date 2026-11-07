## ============================================================================================= ##
#  modules/manifests/core/cert-manager/wildcard.tf                                                #
#                                                                                                 #
#  Issues a wildcard Certificate for *.dns_domain via the ClusterIssuer in issuer.tf.             #
#  The resulting Secret is annotated for Reflector to sync into configured namespaces.            #
#  Uses null_resource + kubectl because the kubernetes provider does not support CRDs well.       #
#  Apply stamps srv.mtaha.dev/tf-owner on the live object; destroy deletes it only when the       #
#  annotation still matches this instance, so a replacement never gaps the object.                #
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

resource "null_resource" "certificate" {
  triggers = {
    name         = local.certificate_name
    namespace    = kubernetes_namespace_v1.this.metadata[0].name
    manifest_sha = sha256(local.certificate)
  }
  lifecycle {
    create_before_destroy = true
  }
  provisioner "local-exec" {
    command = "{ kubectl apply -f - <<EOF\n${local.certificate}\nEOF\n} && kubectl annotate --overwrite certificate ${self.triggers.name} -n ${self.triggers.namespace} srv.mtaha.dev/tf-owner=${self.id}"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "owner=$(kubectl get certificate ${self.triggers.name} -n ${self.triggers.namespace} -o jsonpath='{.metadata.annotations.srv\\.mtaha\\.dev/tf-owner}' 2>/dev/null || true); [ \"$${owner}\" = \"${self.id}\" ] && kubectl delete certificate ${self.triggers.name} -n ${self.triggers.namespace} --ignore-not-found=true || true"
  }
  depends_on = [null_resource.clusterissuer]
}
