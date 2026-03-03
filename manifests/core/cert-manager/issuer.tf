#~ https://github.com/hashicorp/terraform-provider-kubernetes/issues/2673
#~ https://github.com/hashicorp/terraform-provider-kubernetes/issues/2777
#~ https://www.google.com/search?q=hashicorp+kubernetes+api+did+not+recognize+groupversionkind

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
        email  = "mt190502@mtaha.dev"
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

data "external" "clusterissuer_exists" {
  program = [
    "bash",
    "-c",
    "kubectl get clusterissuer ${local.clusterissuer_name} >/dev/null 2>&1 && echo '{\"exists\":\"true\"}' || echo '{\"exists\":\"false\"}'",
  ]
}

resource "null_resource" "clusterissuer" {
  triggers = {
    name         = local.clusterissuer_name
    manifest_sha = sha256(local.clusterissuer)
    exists       = data.external.clusterissuer_exists.result.exists
  }

  provisioner "local-exec" {
    command = "[ \"true\" = \"${self.triggers.exists}\" ] || kubectl apply -f - <<EOF\n${local.clusterissuer}\nEOF"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "[ \"true\" = \"${self.triggers.exists}\" ] && kubectl delete clusterissuer ${self.triggers.name} --ignore-not-found=true || true"
  }

  depends_on = [
    helm_release.this
  ]
}