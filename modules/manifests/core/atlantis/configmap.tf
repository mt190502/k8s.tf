## ============================================================================================= ##
#  modules/manifests/core/atlantis/configmap.tf                                                   #
## ============================================================================================= ##
locals {
  envs = [
    { env = { name = "AWS_ACCESS_KEY_ID", command = "cat /etc/secrets/aws_access_key" } },
    { env = { name = "AWS_SECRET_ACCESS_KEY", command = "cat /etc/secrets/aws_secret_key" } },
    { env = { name = "SOPS_AGE_KEY_FILE", value = "/etc/secrets/sops_age_key" } },
    { env = { name = "STACK_ENV", value = "prod" } },
    { env = { name = "TERRAGRUNT_SECRETS", command = "echo $PWD/prod.secrets.hcl" } },
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
          workflow               = "terragrunt"
          pre_workflow_hooks = [
            {
              description = "Generate terragrunt stack and atlantis.yaml"
              shell       = "bash"
              shellArgs   = "-cv"
              run         = <<-EOC
                set -euo pipefail
                export PATH="/plugins:$PATH"
                export STACK_ENV=prod
                export TERRAGRUNT_SECRETS="$PWD/prod.secrets.hcl"
                git fetch origin "$${BASE_BRANCH_NAME}:refs/remotes/origin/$${BASE_BRANCH_NAME}" --depth=1 >/dev/null 2>&1 || true
                if grep -q 'BEGIN AGE ENCRYPTED FILE' prod.secrets.hcl 2>/dev/null; then
                  sops -d -i prod.secrets.hcl
                  echo "Decrypted prod.secrets.hcl"
                fi
                terragrunt stack generate
                STACK_BASE=".terragrunt-stack/manifests/.terragrunt-stack"
                if [ ! -d "$STACK_BASE" ]; then
                  echo "ERROR: $STACK_BASE not found after stack generate"
                  exit 1
                fi
                {
                  echo 'version: 3'
                  echo 'automerge: true'
                  echo 'projects:'
                  for unit_dir in "$STACK_BASE"/core/* "$STACK_BASE"/apps/*; do
                    [ -d "$unit_dir" ] || continue
                    [ -f "$unit_dir/terragrunt.hcl" ] || continue
                    unit_rel="$${unit_dir#$STACK_BASE/}"
                    category="$${unit_rel%%/*}"
                    name="$${unit_rel#*/}"
                    depth=$(echo "$unit_dir" | tr -cd '/' | wc -c)
                    depth=$((depth + 1))
                    up=$(printf '../%.0s' $(seq 1 $depth))
                    echo "  - name: $unit_rel"
                    echo "    dir: $unit_dir"
                    echo "    workflow: terragrunt"
                    echo "    autoplan:"
                    echo "      enabled: true"
                    echo "      when_modified:"
                    echo "        - \"$${up}modules/common.hcl\""
                    echo "        - \"$${up}modules/manifests/$category/$name/**/*.hcl\""
                    echo "        - \"$${up}modules/manifests/$category/$name/**/*.tf\""
                    echo "        - \"$${up}modules/manifests/terragrunt.stack.hcl\""
                  done
                } > atlantis.yaml
                echo "Generated atlantis.yaml with $(grep -c '  - name:' atlantis.yaml) projects"
              EOC
            }
          ]
        }
      ]
      workflows = {
        terragrunt = {
          plan = {
            steps = concat(local.envs, [
              {
                run = {
                  command = <<-EOC
                    set -euo pipefail
                    export PATH="/plugins:$PATH"
                    if ! grep -qE '^\s*(include|terraform)\s' terragrunt.hcl 2>/dev/null; then
                      echo "Skipping parent config directory (not a leaf module)"
                      exit 0
                    fi
                    REPO_ROOT=$(git rev-parse --show-toplevel)
                    if grep -q 'BEGIN AGE ENCRYPTED FILE' "$REPO_ROOT/prod.secrets.hcl" 2>/dev/null; then
                      sops -d -i "$REPO_ROOT/prod.secrets.hcl"
                      echo "Decrypted prod.secrets.hcl"
                    fi
                    kubectl cluster-info > /dev/null 2>&1 || { echo "Error: kubeconfig is not valid or cluster is not reachable"; exit 1; }
                    if ! grep -qE '^\s*infra\s*=\s*\{' "$REPO_ROOT/prod.values.hcl"; then
                      echo "Error: Mock mode detected - cannot plan with mock values"
                      exit 1
                    fi
                    terragrunt init --non-interactive -input=false -no-color
                    terragrunt plan --non-interactive -input=false -no-color -out=$PLANFILE
                  EOC
                  output  = "hide"
                }
              }
            ])
          }
          apply = {
            steps = concat(local.envs, [
              {
                run = {
                  command = <<-EOC
                    set -euo pipefail
                    export PATH="/plugins:$PATH"
                    if ! grep -qE '^\s*(include|terraform)\s' terragrunt.hcl 2>/dev/null; then
                      echo "Skipping parent config directory (not a leaf module)"
                      exit 0
                    fi
                    REPO_ROOT=$(git rev-parse --show-toplevel)
                    if grep -q 'BEGIN AGE ENCRYPTED FILE' "$REPO_ROOT/prod.secrets.hcl" 2>/dev/null; then
                      sops -d -i "$REPO_ROOT/prod.secrets.hcl"
                      echo "Decrypted prod.secrets.hcl"
                    fi
                    kubectl cluster-info > /dev/null 2>&1 || { echo "Error: kubeconfig is not valid or cluster is not reachable"; exit 1; }
                    if ! grep -qE '^\s*infra\s*=\s*\{' "$REPO_ROOT/prod.values.hcl"; then
                      echo "Error: Mock mode detected - cannot apply with mock values"
                      exit 1
                    fi
                    find "$REPO_ROOT" -type f -iname '*public-domains.csv' -delete || true
                    terragrunt apply --non-interactive -input=false -no-color $PLANFILE
                  EOC
                }
              }
            ])
          }
        }
      }
    })
  }
  depends_on = [kubernetes_namespace_v1.this]
}
