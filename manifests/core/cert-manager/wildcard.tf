locals {
  certificate_name = "wildcard-mtaha.dev-tls"
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
          "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces" = "adguard-home,radicale"
          "reflector.v1.k8s.emberstack.com/reflection-auto-enabled"       = "true"
          "reflector.v1.k8s.emberstack.com/reflection-auto-namespaces"    = "adguard-home,radicale"
        }
      }
      dnsNames = [
        "mtaha.dev",
        "*.mtaha.dev"
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

  provisioner "local-exec" {
    command = "kubectl apply -f - <<EOF\n${local.certificate}\nEOF"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete certificate wildcard-mtaha.dev-tls -n ${self.triggers.namespace} --ignore-not-found=true"
  }

  depends_on = [
    helm_release.this
  ]
}