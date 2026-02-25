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

resource "null_resource" "clusterissuer" {
  triggers = {
    name         = local.clusterissuer_name
    manifest_sha = sha256(local.clusterissuer)
  }

  provisioner "local-exec" {
    command = "kubectl apply -f - <<EOF\n${local.clusterissuer}\nEOF"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete clusterissuer ${self.triggers.name} --ignore-not-found=true"
  }

  depends_on = [
    helm_release.this
  ]
}