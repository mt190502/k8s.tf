## ============================================================================================= ##
#  common.hcl --- Shared configuration for all Terragrunt units                                   #
#                                                                                                 #
#  This file provides:                                                                            #
#    - Backend configuration (local or S3)                                                        #
#    - Common locals and helpers                                                                  #
#                                                                                                 #
#  Include in your terragrunt.hcl:                                                                #
#    include "common" {                                                                           #
#      path   = find_in_parent_folders("modules/common.hcl")                                      #
#      expose = true                                                                              #
#    }                                                                                            #
#                                                                                                 #
#  Environment variables:                                                                         #
#    TF_BACKEND_TYPE   - "local" (default) or "s3"                                                #
#    TF_STATE_DIR      - State directory for local backend (default: .terraform)                  #
#    TF_S3_BUCKET      - S3 bucket name (required if TF_BACKEND_TYPE=s3)                          #
#    TF_S3_KEY_PREFIX  - Key prefix for S3 state (optional)                                       #
#    TF_S3_REGION      - S3 region (default: auto)                                                #
#    TF_S3_ENDPOINT    - S3 endpoint for MinIO etc (optional)                                     #
## ============================================================================================= ##
locals {
  backend_type     = get_env("TF_BACKEND_TYPE", "local")
  state_dir        = get_env("TF_STATE_DIR", "${get_repo_root()}/.terraform")
  s3_bucket        = get_env("TF_S3_BUCKET", "")
  s3_key_prefix    = get_env("TF_S3_KEY_PREFIX", "")
  s3_region        = get_env("TF_S3_REGION", "auto")
  s3_endpoint      = get_env("TF_S3_ENDPOINT", "")
  repo_root        = get_repo_root()
  unit_path        = trimprefix(get_terragrunt_dir(), "${local.repo_root}/")
  local_state_path = "${local.state_dir}/${local.unit_path}/terraform.tfstate"
  s3_key           = "${local.s3_key_prefix}${local.unit_path}/terraform.tfstate"
  providers = {
    cloudflare = { version = "~> 5.18.0" }
    external   = { version = "~> 2.3.1" }
    hcloud     = { version = "~> 1.60.1" }
    helm       = { version = "~> 3.1.1" }
    kubernetes = { version = "~> 3.0.1" }
    null       = { version = "~> 3.2.4" }
    tailscale  = { version = "~> 0.28.0" }
    talos      = { version = "~> 0.10.1" }
  }

  ## --------------------------------------------------------------------------------------------- ##
  #  Shared mock outputs for dependency blocks (plan/validate without state).                       #
  ## --------------------------------------------------------------------------------------------- ##
  skip_outputs_commands                   = ["plan", "validate", "init", "destroy"]
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs_merge_strategy_with_state  = "no_merge"

  mock_node_full = {
    name         = "mock-node"
    role         = "controlplane"
    arch         = "arm64"
    location     = "fsn1"
    ipv4_address = "1.2.3.4"
    ipv6_address = "::1"
    private_ip   = null
    taints       = []
  }

  mock_nodes_full = {
    (local.mock_node_full.name) = local.mock_node_full
  }

  mock_node_minimal = {
    name         = "mock-node"
    role         = "controlplane"
    arch         = "arm64"
    ipv4_address = "1.2.3.4"
    ipv6_address = "::1"
  }

  mock_nodes_minimal = {
    (local.mock_node_minimal.name) = local.mock_node_minimal
  }

  mock_tailscale_ipv4 = {
    (local.mock_node_minimal.name) = "100.64.0.1"
  }

  mock_tailscale_ipv6 = {
    (local.mock_node_minimal.name) = "fd7a:115c:a1e0::1"
  }

  ## --------------------------------------------------------------------------------------------- ##
  #  Provider placeholders to allow `plan` with empty stack secrets.                                #
  #  These are only used when stack values don't supply real secrets.                               #
  ## --------------------------------------------------------------------------------------------- ##
  mock_hcloud_api_token       = "0000000000000000000000000000000000000000000000000000000000000000"
  mock_cloudflare_api_token   = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  mock_cloudflare_zone_id     = "mock-zone-id"
  mock_tailscale_auth_key     = "mock-tailscale-auth-key"
  mock_tailscale_oauth_id     = "mock-tailscale-client-id"
  mock_tailscale_oauth_secret = "mock-tailscale-client-secret"
  mock_tailscale_tailnet      = "mock-tailnet"
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = (
    local.backend_type == "s3"
    ? <<-EOT
      terraform {
        backend "s3" {
          bucket                      = "${local.s3_bucket}"
          key                         = "${local.s3_key}"
          region                      = "${local.s3_region}"
          endpoint                    = "${local.s3_endpoint}"
          skip_credentials_validation = true
          skip_metadata_api_check     = true
          skip_requesting_account_id  = true
        }
      }
      EOT
    : <<-EOT
      terraform {
        backend "local" {
          path = "${local.local_state_path}"
        }
      }
      EOT
  )
}
