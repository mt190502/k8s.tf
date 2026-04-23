## ============================================================================================= ##
#  modules/manifests/core/atlantis/main.tf                                                        #
## ============================================================================================= ##
locals {
  # renovate datasource=github-releases depName=kubernetes/kubernetes
  kubectl_version = "v1.34.1"

  # renovate datasource=github-releases depName=jqlang/jq
  jq_version = "1.8.1"

  # renovate datasource=github-releases depName=gruntwork-io/terragrunt
  terragrunt_version = "v0.93.8"

  # renovate datasource=github-releases depName=opentofu/opentofu
  opentofu_version = "1.10.9"

  # renovate datasource=github-releases depName=getsops/sops
  sops_version = "3.12.1"
}

resource "helm_release" "atlantis" {
  count      = var.enabled ? 1 : 0
  name       = var.config.name
  namespace  = kubernetes_namespace_v1.this[0].metadata[0].name
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  version    = "6.3.0"

  values = [yamlencode({
    atlantisUrl           = "https://${var.config.hostname}.${var.config.domain}"
    orgAllowlist          = var.config.repo_allowlist
    logLevel              = "info"
    defaultTFDistribution = "opentofu"
    githubApp = {
      id             = try(var.secrets.app.github_app_id, "")
      installationId = try(var.secrets.app.github_installation_id, "")
      slug           = var.config.github_app_slug
      key            = try(var.secrets.app.github_app_key, "")
      secret         = try(var.secrets.app.webhook_secret, "")
    }
    image = {
      repository = "ghcr.io/runatlantis/atlantis"
      tag        = var.config.image_tag
      pullPolicy = "Always"
    }
    replicaCount = 1
    service = {
      type       = "ClusterIP"
      port       = 80
      targetPort = 4141
      portName   = "atlantis"
    }
    ingress = {
      enabled = false
    }
    route = {
      webhook = {
        enabled    = true
        apiVersion = "gateway.networking.k8s.io/v1"
        kind       = "HTTPRoute"
        hostnames  = ["${var.config.hostname}.${var.config.domain}"]
        parentRefs = [
          {
            name      = var.config.gateway_name
            namespace = var.config.gateway_namespace
          }
        ]
        matches = [
          {
            path = {
              type  = "PathPrefix"
              value = "/events"
            }
          }
        ]
      }
      ui = {
        enabled    = true
        apiVersion = "gateway.networking.k8s.io/v1"
        kind       = "HTTPRoute"
        hostnames  = ["${var.config.hostname}.${var.config.domain}"]
        parentRefs = [
          {
            name      = var.config.gateway_name
            namespace = var.config.gateway_namespace
          }
        ]
        matches = [
          {
            path = {
              type  = "PathPrefix"
              value = "/"
            }
          }
        ]
        filters = var.config.basic_auth && var.config.preferred_gateway == "traefik" ? [
          {
            type = "ExtensionRef"
            extensionRef = {
              group = "traefik.io"
              kind  = "Middleware"
              name  = "${var.config.name}-basic-auth"
            }
          }
        ] : []
      }
    }
    resources = {
      requests = {
        memory = "512Mi"
        cpu    = "250m"
      }
      limits = {
        memory = "2Gi"
        cpu    = "1"
      }
    }
    volumeClaim = {
      enabled     = true
      dataStorage = "1Gi"
      accessModes = ["ReadWriteOnce"]
    }
    atlantisDataDirectory = "/atlantis-data"
    loadEnvFromSecrets    = ["${var.config.name}-secrets"]
    extraVolumes = [
      { name = "repo-config", configMap = { name = "${var.config.name}-repo-config" } },
      { name = "kubeconfig", configMap = { name = "${var.config.name}-kubeconfig" } },
      { name = "runtime-secrets", secret = { secretName = "${var.config.name}-secrets" } }
    ]
    extraVolumeMounts = [
      { name = "repo-config", mountPath = "/etc/atlantis", readOnly = true },
      { name = "kubeconfig", mountPath = "/etc/kube", readOnly = true },
      { name = "kubeconfig", mountPath = "/home/atlantis/.kube", readOnly = true },
      { name = "runtime-secrets", mountPath = "/etc/secrets", readOnly = true }
    ]
    environment = {
      ATLANTIS_AUTOMERGE   = "true"
      ATLANTIS_REPO_CONFIG = "/etc/atlantis/atlantis.yaml"
      KUBECONFIG           = "/etc/kube/config"
      KUBE_CONFIG_PATH     = "/etc/kube/config"
      TF_IN_AUTOMATION     = "true"
      TF_BACKEND_TYPE      = "s3"
      SOPS_AGE_KEY_FILE    = "/etc/secrets/sops_age_key"
    }
    extraPath = "/plugins"
    initConfig = {
      enabled           = true
      image             = "debian:bookworm-slim"
      imagePullPolicy   = "IfNotPresent"
      sharedDir         = "/plugins"
      sharedDirReadOnly = true
      workDir           = "/tmp"
      sizeLimit         = "1Gi"
      containerSecurityContext = {
        runAsUser = 0
      }
      script = <<-SCRIPT
        #!/bin/bash
        set -euxo pipefail
        
        apt-get update && apt-get install -y --no-install-recommends make wget ca-certificates curl
        cp /usr/bin/make "$${INIT_SHARED_DIR}/make"
        chmod 755 "$${INIT_SHARED_DIR}/make"

        JQ_VERSION="${local.jq_version}"
        wget "https://github.com/jqlang/jq/releases/download/jq-$${JQ_VERSION}/jq-linux-amd64" -O "$${INIT_SHARED_DIR}/jq"
        chmod 755 "$${INIT_SHARED_DIR}/jq"

        KUBECTL_VERSION="${local.kubectl_version}"
        wget "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -O "$${INIT_SHARED_DIR}/kubectl"
        chmod 755 "$${INIT_SHARED_DIR}/kubectl"
        
        TG_VERSION="${local.terragrunt_version}"
        wget "https://github.com/gruntwork-io/terragrunt/releases/download/$${TG_VERSION}/terragrunt_linux_amd64" -O "$${INIT_SHARED_DIR}/terragrunt"
        chmod 755 "$${INIT_SHARED_DIR}/terragrunt"
        
        TF_VERSION="${local.opentofu_version}"
        wget "https://github.com/opentofu/opentofu/releases/download/v$${TF_VERSION}/tofu_$${TF_VERSION}_linux_amd64.tar.gz"
        tar -xzf "tofu_$${TF_VERSION}_linux_amd64.tar.gz"
        mv tofu "$${INIT_SHARED_DIR}/tofu"
        chmod 755 "$${INIT_SHARED_DIR}/tofu"
        
        SOPS_VERSION="${local.sops_version}"
        wget "https://github.com/getsops/sops/releases/download/v$${SOPS_VERSION}/sops-v$${SOPS_VERSION}.linux.amd64" -O "$${INIT_SHARED_DIR}/sops"
        chmod 755 "$${INIT_SHARED_DIR}/sops"
      SCRIPT
    }
    statefulSet = {
      securityContext = {
        fsGroup             = 1000
        runAsUser           = 100
        fsGroupChangePolicy = "OnRootMismatch"
      }
    }
    serviceAccount = {
      create = true
      mount  = true
    }
    test = {
      enabled = false
    }
  })]
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.atlantis,
    kubernetes_config_map_v1.repo_config,
    kubernetes_config_map_v1.kubeconfig,
    kubernetes_secret_v1.basic_auth,
    kubernetes_manifest.basic_auth_middleware
  ]
}
