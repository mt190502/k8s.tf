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
#    TF_BACKEND_TYPE          --- "local" (default) or "s3"                                       #
#    TF_S3_BUCKET             --- S3 bucket name (required if TF_BACKEND_TYPE=s3)                 #
#    TF_S3_REGION             --- S3 region (default: auto)                                       #
#    TF_S3_ENDPOINT           --- S3 endpoint for MinIO etc (optional)                            #
#    TF_ENCRYPTION_PASSPHRASE --- Optional override for state encryption key                      #
#    TF_FORCE_ENCRYPTION      --- "true" to force encryption (default: false)                     #
## ============================================================================================= ##
locals {
  env              = get_env("STACK_ENV", "dev")
  backend_type     = get_env("TF_BACKEND_TYPE", "local")
  force_encryption = get_env("TF_FORCE_ENCRYPTION", "false") == "true"
  repo_root        = get_repo_root()
  unit_path        = trimprefix(get_terragrunt_dir(), "${local.repo_root}/")
  modules_path     = "modules/${replace(local.unit_path, "/\\.terragrunt-stack\\/?/", "")}"
  local_state_path = "${local.repo_root}/.terraform/${local.env}/${local.modules_path}/terraform.tfstate"

  # S3 backend configuration (used when TF_BACKEND_TYPE=s3)
  s3_bucket   = get_env("TF_S3_BUCKET", "")
  s3_region   = get_env("TF_S3_REGION", "auto")
  s3_endpoint = get_env("TF_S3_ENDPOINT", "")
  s3_key      = "${local.env}/${local.modules_path}/terraform.tfstate"

  ## --------------------------------------------------------------------------------------------- ##
  #  State encryption passphrase:                                                                   #
  #    1) TF_ENCRYPTION_PASSPHRASE (optional override)                                              #
  #    2) Derived from SOPS age private key (no extra password needed)                              #
  ## --------------------------------------------------------------------------------------------- ##
  sops_age_key_file = get_env("SOPS_AGE_KEY_FILE", "${get_env("HOME", "")}/.config/sops/age/keys.txt")
  sops_derived_passphrase = try(trimspace(run_cmd(
    "--terragrunt-quiet",
    "bash",
    "-lc",
    "if [ -f \"${local.sops_age_key_file}\" ]; then grep -m1 '^AGE-SECRET-KEY-' \"${local.sops_age_key_file}\" 2>/dev/null | sha256sum 2>/dev/null | cut -d' ' -f1; fi"
  )), "")
  encryption_passphrase = trimspace(get_env("TF_ENCRYPTION_PASSPHRASE", "")) != "" ? trimspace(get_env("TF_ENCRYPTION_PASSPHRASE", "")) : (local.force_encryption ? local.sops_derived_passphrase : "")


  ## --------------------------------------------------------------------------------------------- ##
  #  Shared mock outputs for dependency blocks (plan/validate without state).                       #
  ## --------------------------------------------------------------------------------------------- ##
  skip_outputs_commands                   = ["validate", "init", "destroy"]
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "destroy"]
  mock_outputs_merge_strategy_with_state  = "shallow"

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

  ## --------------------------------------------------------------------------------------------- ##
  #  Full mock infrastructure configuration for testing/development.                                #
  #  Used when values.hcl is empty or missing infrastructure config.                                #
  ## --------------------------------------------------------------------------------------------- ##
  mock_infra = {
    kubernetes = {
      cluster_name = "mock-cluster"
      cluster_url = {
        dns       = "mock.local"
        main      = "srv.mock.local"
        apiserver = "k8s.srv.mock.local"
      }
      ipcfg = {
        pod = {
          ipv4 = "10.244.0.0/16"
          ipv6 = "2001:db8:42:0::/56"
        }
        service = {
          ipv4 = "10.96.0.0/12"
          ipv6 = "2001:db8:42:1::/112"
        }
      }
      nodes = [
        { name = "mock-cp1", role = "controlplane", taints = [] },
        { name = "mock-w1", role = "worker", taints = [] },
        { name = "mock-w2", role = "worker", taints = [] },
      ]
      preferred_gateway = "cilium"
      overwrite_dns     = false
    }
    cloudflare = {
      enabled = true
    }
    hetzner = {
      enabled = true
      assignments = [
        {
          selector     = { role = "controlplane" }
          architecture = "arm64"
          locations    = ["fsn1", "nbg1", "hel1"]
          strategy     = "roundrobin"
        },
        {
          selector     = { role = "worker" }
          architecture = "arm64"
          locations    = ["fsn1", "nbg1", "hel1"]
          strategy     = "roundrobin"
        }
      ]
      firewall = {
        enabled = true
        rules = [
          {
            short_name  = "https"
            description = "Allow HTTPS traffic"
            protocol    = "tcp"
            direction   = "in"
            port        = "443"
            source_ips  = ["0.0.0.0/0", "::/0"]
          },
          {
            short_name  = "tailscale"
            description = "Allow Tailscale peer connectivity"
            protocol    = "udp"
            direction   = "in"
            port        = "41641"
            source_ips  = ["0.0.0.0/0", "::/0"]
          }
        ]
      }
      images = {
        arm64 = { id = "12345678-arm64", code = "cax11" }
        amd64 = { id = "87654321-amd64", code = "cx33" }
      }
      private_network = {
        enabled = true
        cidr    = "10.0.0.0/16"
      }
    }
    tailscale = {
      enabled = true
    }
    talos = {
      dualstack = true
      kubespan  = true
      kubeprism = true
    }
    versions = {
      talos      = "v1.12.0"
      kubernetes = "v1.35.0"
      cilium     = "1.19.0"
    }
  }

  mock_apps = {
    longhorn = {
      enabled = true
      version = "1.11.0"
    }
    reflector = {
      enabled = true
      version = "10.0.10"
    }
    kube_prometheus_stack = {
      enabled = true
      version = "82.1.0"
    }
    cnpg = {
      enabled = true
      version = "0.27.1"
    }
    cert_manager = {
      enabled    = true
      version    = "v1.19.0"
      acme_email = "mock@example.com"
    }
    traefik = {
      enabled = false
      version = "39.0.6"
    }
    tests = {
      enabled = true
    }
  }
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

generate "encryption" {
  path      = "encryption.tf"
  if_exists = "overwrite_terragrunt"
  contents = (
    local.encryption_passphrase != "" ? <<-EOT
      variable "encryption_passphrase" {
        type        = string
        description = "Passphrase for encrypting Terraform state"
        sensitive   = true
        default     = "${local.encryption_passphrase}"
      }

      terraform {
        encryption {
          key_provider "pbkdf2" "state_key" {
            passphrase = var.encryption_passphrase
          }
          method "aes_gcm" "state_encryption" {
            keys = key_provider.pbkdf2.state_key
          }
          state {
            method   = method.aes_gcm.state_encryption
            enforced = true
          }
        }
      }
      EOT
    : ""
  )
}