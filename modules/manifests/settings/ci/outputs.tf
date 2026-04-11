## ============================================================================================= ##
#  modules/manifests/settings/ci/outputs.tf                                                       #
#                                                                                                 #
#  Outputs for CI settings module.                                                                #
#                                                                                                 #
#    kubeconfig           --- Kubeconfig for CI service account                                   #
#    service_account_name --- Name of the CI service account                                      #
#    namespace            --- Namespace where CI RBAC resources are created                       #
## ============================================================================================= ##
output "kubeconfig" {
  description = "Restricted CI kubeconfig"
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = var.config.cluster_name
      cluster = {
        server                     = var.config.apiserver
        certificate-authority-data = base64encode(data.kubernetes_config_map_v1.kube_root_ca[0].data["ca.crt"])
      }
    }]
    contexts = [{
      name = "${var.config.service_account_name}@${var.config.cluster_name}"
      context = {
        cluster   = var.config.cluster_name
        user      = var.config.service_account_name
        namespace = var.config.namespace
      }
    }]
    current-context = "${var.config.service_account_name}@${var.config.cluster_name}"
    users = [{
      name = var.config.service_account_name
      user = {
        token = data.kubernetes_secret_v1.ci_token[0].data.token
      }
    }]
  })
  sensitive = true
}

output "service_account_name" {
  description = "CI service account name"
  value       = var.config.service_account_name
}

output "namespace" {
  description = "Namespace where CI RBAC resources live"
  value       = var.config.namespace
}
