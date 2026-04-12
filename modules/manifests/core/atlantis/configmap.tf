## ============================================================================================= ##
#  modules/manifests/core/atlantis/configmap.tf                                                   #
## ============================================================================================= ##
locals {
  envs = [
    { env = { name = "AWS_ACCESS_KEY_ID", command = "cat /etc/secrets/aws_access_key" } },
    { env = { name = "AWS_SECRET_ACCESS_KEY", command = "cat /etc/secrets/aws_secret_key" } },
    { env = { name = "SOPS_AGE_KEY_FILE", value = "/etc/secrets/sops_age_key" } },
    { env = { name = "TF_BACKEND_TYPE", value = "s3" } },
    { env = { name = "TF_ENCRYPTION_PASSPHRASE", command = "cat /etc/secrets/tf_encryption_pass" } },
    { env = { name = "TF_IN_AUTOMATION", value = "true" } },
    { env = { name = "TF_S3_BUCKET", command = "cat /etc/secrets/aws_s3_bucket" } },
    { env = { name = "TF_S3_ENDPOINT", command = "cat /etc/secrets/aws_s3_endpoint" } },
    { env = { name = "TF_S3_REGION", value = var.config.aws_s3_region } },
  ]
}

resource "kubernetes_config_map_v1" "repo_config" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-repo-config"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    "atlantis.yaml" = yamlencode({
      repos = [
        {
          id                     = "/.*/"
          plan_requirements      = ["approved", "mergeable", "undiverged"]
          apply_requirements     = ["approved", "mergeable", "undiverged"]
          allow_custom_workflows = true
          allowed_overrides      = ["workflow", "apply_requirements"]
        }
      ]
      workflows = {
        terragrunt = {
          plan = {
            steps = concat(local.envs, [{ run = { command = "make decrypt && yes | make manifests-plan" } }])
          }
          apply = {
            steps = concat(local.envs, [{ run = { command = "make decrypt && yes | make manifests-apply" } }])
          }
        }
      }
    })
  }
  depends_on = [kubernetes_namespace_v1.this]
}