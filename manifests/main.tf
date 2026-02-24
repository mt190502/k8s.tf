##~ Apps
module "apps" {
  source = "./apps"
}


##~ Core components
module "core_cert-manager" {
  source = "./core/cert-manager"
  cf_api_token = var.cf_api_token
}

module "core_cnpg" {
  source = "./core/cnpg"
}

module "core_kube-prometheus-stack" {
  source = "./core/kube-prometheus-stack"
}

module "core_longhorn" {
  source = "./core/longhorn"
}

module "core_reflector" {
  source = "./core/reflector"
}