## ============================================================================================= ##
#  modules/manifests/core/atlantis/main.tf                                                           #
## ============================================================================================= ##
resource "helm_release" "atlantis" {
  count      = var.enabled ? 1 : 0
  name       = var.config.name
  namespace  = kubernetes_namespace_v1.this[0].metadata[0].name
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  version    = "6.2.0"

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
        cpu    = "100m"
      }
      limits = {
        memory = "1Gi"
        cpu    = "500m"
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
      { name = "runtime-secrets", secret = { secretName = "${var.config.name}-secrets" } }
    ]
    extraVolumeMounts = [
      { name = "repo-config", mountPath = "/etc/atlantis", readOnly = true },
      { name = "runtime-secrets", mountPath = "/etc/secrets", readOnly = true }
    ]
    environment = {
      ATLANTIS_REPO_CONFIG = "/etc/atlantis/atlantis.yaml"
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
      sizeLimit         = "250Mi"
      containerSecurityContext = {
        runAsUser = 0
      }
      script = <<-SCRIPT
        #!/bin/bash
        set -euxo pipefail
        
        apt-get update && apt-get install -y --no-install-recommends make wget ca-certificates jq curl
        cp /usr/bin/make "$${INIT_SHARED_DIR}/make"
        chmod 755 "$${INIT_SHARED_DIR}/make"
        
        # renovate datasource=github-releases depName=gruntwork-io/terragrunt
        TG_VERSION="v0.93.8"
        wget "https://github.com/gruntwork-io/terragrunt/releases/download/$${TG_VERSION}/terragrunt_linux_amd64" -O "$${INIT_SHARED_DIR}/terragrunt"
        chmod 755 "$${INIT_SHARED_DIR}/terragrunt"
        
        # renovate datasource=github-releases depName=opentofu/opentofu
        TF_VERSION="1.10.9"
        wget "https://github.com/opentofu/opentofu/releases/download/v$${TF_VERSION}/tofu_$${TF_VERSION}_linux_amd64.tar.gz"
        tar -xzf "tofu_$${TF_VERSION}_linux_amd64.tar.gz"
        mv tofu "$${INIT_SHARED_DIR}/tofu"
        chmod 755 "$${INIT_SHARED_DIR}/tofu"
        
        # renovate datasource=github-releases depName=getsops/sops
        SOPS_VERSION="3.12.1"
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
    kubernetes_secret_v1.basic_auth,
    kubernetes_manifest.basic_auth_middleware
  ]
}