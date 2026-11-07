## ============================================================================================= ##
#  modules/manifests/core/cert-manager/issuer.tf                                                  #
#                                                                                                 #
#  Creates a Let's Encrypt ClusterIssuer (ACME DNS01 via Cloudflare).                             #
#  Uses null_resource + kubectl because the kubernetes provider does not support CRDs well.       #
#  Apply stamps srv.mtaha.dev/tf-owner on the live object; destroy deletes it only when the       #
#  annotation still matches this instance, so a replacement never gaps the object.                #
#  Refs: https://github.com/hashicorp/terraform-provider-kubernetes/issues/2673                   #
#        https://github.com/hashicorp/terraform-provider-kubernetes/issues/2777                   #
## ============================================================================================= ##
locals {
  clusterissuer_name = "mainissuer"
  clusterissuer = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = local.clusterissuer_name
    }
    spec = {
      acme = {
        email  = var.config.acme_email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "issuer-account-key"
        }
        solvers = [
          {
            dns01 = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = kubernetes_secret_v1.this.metadata[0].name
                  key  = "cf-api-token"
                }
              }
            }
          }
        ]
      }
    }
  })
}

resource "null_resource" "clusterissuer" {
  triggers = {
    name         = local.clusterissuer_name
    manifest_sha = sha256(local.clusterissuer)
  }
  lifecycle {
    create_before_destroy = true
  }
  provisioner "local-exec" {
    command = "{ kubectl apply -f - <<EOF\n${local.clusterissuer}\nEOF\n} && kubectl annotate --overwrite clusterissuer ${self.triggers.name} srv.mtaha.dev/tf-owner=${self.id}"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "owner=$(kubectl get clusterissuer ${self.triggers.name} -o jsonpath='{.metadata.annotations.srv\\.mtaha\\.dev/tf-owner}' 2>/dev/null || true); [ \"$${owner}\" = \"${self.id}\" ] && kubectl delete clusterissuer ${self.triggers.name} --ignore-not-found=true || true"
  }
  depends_on = [helm_release.this]
}
