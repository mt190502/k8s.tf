## ============================================================================================= ##
#  modules/manifests/core/atlantis/main.tf                                                        #
## ============================================================================================= ##
locals {
  # renovate: datasource=github-releases depName=kubernetes/kubernetes
  kubectl_version = "v1.36.0"

  # renovate: datasource=github-releases depName=jqlang/jq
  jq_version = "1.8.1"

  # renovate: datasource=github-releases depName=gruntwork-io/terragrunt
  terragrunt_version = "v1.0.3"

  # renovate: datasource=github-releases depName=opentofu/opentofu
  opentofu_version = "1.11.6"

  # renovate: datasource=github-releases depName=getsops/sops
  sops_version = "3.12.2"
}

resource "helm_release" "atlantis" {
  count      = var.enabled ? 1 : 0
  name       = var.config.name
  namespace  = kubernetes_namespace_v1.this[0].metadata[0].name
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  version    = "6.4.0"
  set = [
    {
      name  = "atlantisUrl"
      value = "https://${var.config.hostname}.${var.config.domain}"
    },
    {
      name  = "orgAllowlist"
      value = var.config.repo_allowlist
    },
    {
      name  = "logLevel"
      value = "info"
    },
    {
      name  = "defaultTFDistribution"
      value = "opentofu"
    },
    {
      name  = "githubApp.id"
      value = try(var.secrets.app.github_app_id, "")
    },
    {
      name  = "githubApp.installationId"
      value = try(var.secrets.app.github_installation_id, "")
    },
    {
      name  = "githubApp.slug"
      value = var.config.github_app_slug
    },
    {
      name  = "replicaCount"
      value = 1
    },
    # Atlantis may apply changes to its own Helm release. With a single replica,
    # a StatefulSet rolling update will terminate the running pod and interrupt
    # the in-flight `atlantis apply`. OnDelete keeps the pod running; restart it
    # manually after the apply to pick up new image/config.
    {
      name  = "statefulSet.updateStrategy.type"
      value = "OnDelete"
    },
    {
      name  = "service.type"
      value = "ClusterIP"
    },
    {
      name  = "service.port"
      value = 80
    },
    {
      name  = "service.targetPort"
      value = 4141
    },
    {
      name  = "service.portName"
      value = "atlantis"
    },
    {
      name  = "ingress.enabled"
      value = false
    },
    {
      name  = "route.webhook.enabled"
      value = true
    },
    {
      name  = "route.webhook.apiVersion"
      value = "gateway.networking.k8s.io/v1"
    },
    {
      name  = "route.webhook.kind"
      value = "HTTPRoute"
    },
    {
      name  = "route.webhook.hostnames[0]"
      value = "${var.config.hostname}.${var.config.domain}"
    },
    {
      name  = "route.webhook.parentRefs[0].name"
      value = var.config.gateway_name
    },
    {
      name  = "route.webhook.parentRefs[0].namespace"
      value = var.config.gateway_namespace
    },
    {
      name  = "route.webhook.matches[0].path.type"
      value = "PathPrefix"
    },
    {
      name  = "route.webhook.matches[0].path.value"
      value = "/events"
    },
    {
      name  = "route.ui.enabled"
      value = true
    },
    {
      name  = "route.ui.apiVersion"
      value = "gateway.networking.k8s.io/v1"
    },
    {
      name  = "route.ui.kind"
      value = "HTTPRoute"
    },
    {
      name  = "route.ui.hostnames[0]"
      value = "${var.config.hostname}.${var.config.domain}"
    },
    {
      name  = "route.ui.parentRefs[0].name"
      value = var.config.gateway_name
    },
    {
      name  = "route.ui.parentRefs[0].namespace"
      value = var.config.gateway_namespace
    },
    {
      name  = "route.ui.matches[0].path.type"
      value = "PathPrefix"
    },
    {
      name  = "route.ui.matches[0].path.value"
      value = "/"
    },
    {
      name  = "resources.requests.memory"
      value = "512Mi"
    },
    {
      name  = "resources.requests.cpu"
      value = "250m"
    },
    {
      name  = "resources.limits.memory"
      value = "2Gi"
    },
    {
      name  = "resources.limits.cpu"
      value = "1"
    },
    {
      name  = "volumeClaim.enabled"
      value = true
    },
    {
      name  = "volumeClaim.dataStorage"
      value = "1Gi"
    },
    {
      name  = "volumeClaim.accessModes[0]"
      value = "ReadWriteOnce"
    },
    {
      name  = "atlantisDataDirectory"
      value = "/atlantis-data"
    },
    {
      name  = "loadEnvFromSecrets[0]"
      value = "${var.config.name}-secrets"
    },
    {
      name  = "extraPath"
      value = "/plugins"
    },
    {
      name  = "initConfig.enabled"
      value = true
    },
    {
      name  = "initConfig.image"
      value = "debian:bookworm-slim"
    },
    {
      name  = "initConfig.imagePullPolicy"
      value = "IfNotPresent"
    },
    {
      name  = "initConfig.sharedDir"
      value = "/plugins"
    },
    {
      name  = "initConfig.sharedDirReadOnly"
      value = true
    },
    {
      name  = "initConfig.workDir"
      value = "/tmp"
    },
    {
      name  = "initConfig.sizeLimit"
      value = "1Gi"
    },
    {
      name  = "initConfig.containerSecurityContext.runAsUser"
      value = 0
    },
    {
      name  = "statefulSet.securityContext.fsGroup"
      value = 1000
    },
    {
      name  = "statefulSet.securityContext.runAsUser"
      value = 100
    },
    {
      name  = "statefulSet.securityContext.fsGroupChangePolicy"
      value = "OnRootMismatch"
    },
    {
      name  = "serviceAccount.create"
      value = true
    },
    {
      name  = "serviceAccount.mount"
      value = true
    },
    {
      name  = "test.enabled"
      value = false
    }
  ]
  set_sensitive = [
    {
      name  = "githubApp.key"
      value = try(var.secrets.app.github_app_key, "")
    },
    {
      name  = "githubApp.secret"
      value = try(var.secrets.app.webhook_secret, "")
    }
  ]
  values = [yamlencode({
    route = {
      ui = {
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
    initConfig = {
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
