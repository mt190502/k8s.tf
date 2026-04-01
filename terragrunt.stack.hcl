## ============================================================================================= ##
# terragrunt.stack.hcl --- Root stack definition                                                  #
#                                                                                                 #
# Infrastructure:  hetzner + tailscale + cloudflare + talos                                       #
# Applications:    core/apps --- each app is a separate unit                                      #
#                                                                                                 #
# Apply order (driven by dependency blocks in each module's terragrunt.hcl):                      #
#                                                                                                 #
#   talos/pre                                                                                     #
#     └─> hetzner/post                                                                            #
#           └─> tailscale/post                                                                    #
#                 └─> talos/post                                                                  #
#                       └─> cloudflare/post                                                       #
#                             └─> longhorn                                                        #
#                                   └─> reflector                                                 #
#                                   └─> cnpg                                                      #
#                                   └─> kube-prometheus-stack                                     #
#                                         └─> cert-manager                                        #
#                                                                                                 #
# Usage:                                                                                          #
#   make plan  ENV=prod                                                                           #
#   make apply ENV=prod                                                                           #
## ============================================================================================= ##
locals {
  v         = read_terragrunt_config("${get_repo_root()}/${get_env("STACK_ENV", "dev")}.values.hcl").locals
  s         = read_terragrunt_config(get_env("TERRAGRUNT_SECRETS", "${get_repo_root()}/secrets.hcl")).locals
  c         = read_terragrunt_config("${get_repo_root()}/modules/common.hcl")
  infra     = try(local.v.infra, null) != null ? local.v.infra : local.c.locals.mock_infra
  manifests = try(local.v.manifests, {})
}

## --------------------------------------------------------------------------------------------- ##
#  Root wiring: infra stack + manifests stack                                                     #
#                                                                                                 #
#  Each sub-stack receives raw values and handles its own normalization/secret injection.         #
## --------------------------------------------------------------------------------------------- ##
stack "infra" {
  source = "./modules/infra"
  path   = "infra"
  values = {
    infra   = local.infra
    secrets = try(local.s.infra, {})
  }
}

stack "manifests" {
  source = "./modules/manifests"
  path   = "manifests"
  values = {
    manifests = local.manifests
    secrets   = local.s
    infra     = local.infra
  }
}