## ============================================================================================= ##
#  modules/manifests/core/traefik/helm.tf                                                         #
#                                                                                                 #
#  Traefik deployment in Gateway API mode (daemonset).                                            #
#  Gateway API CRDs are skipped (already installed by Cilium).                                    #
#  Traefik CRDs (Middleware, TLSStore) applied directly via kubectl.                              #
## ============================================================================================= ##
resource "null_resource" "crds" {
  count = var.enabled ? 1 : 0

  triggers = {
    # renovate = datasource=helm depName=traefik-crds registryUrl=https://traefik.github.io/charts
    crd_version = "1.16.0"
  }

  provisioner "local-exec" {
    command = <<-CMD
      helm template traefik-crds oci://ghcr.io/traefik/helm/traefik-crds \
        --version ${self.triggers.crd_version} \
        --set traefik=true \
        --set gatewayAPI=false | kubectl apply --server-side --force-conflicts -f -
    CMD
  }

  provisioner "local-exec" {
    on_failure = continue
    when       = destroy
    command    = <<-CMD
      helm template traefik-crds oci://ghcr.io/traefik/helm/traefik-crds \
        --version ${self.triggers.crd_version} \
        --set traefik=true \
        --set gatewayAPI=false | kubectl delete -f -
    CMD
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "helm_release" "this" {
  count           = var.enabled ? 1 : 0
  name            = "traefik"
  repository      = "https://traefik.github.io/charts"
  chart           = "traefik"
  version         = "40.0.0"
  namespace       = kubernetes_namespace_v1.this[0].metadata[0].name
  upgrade_install = true
  skip_crds       = true
  set = [
    {
      name  = "deployment.kind"
      value = "DaemonSet"
    },
    {
      name  = "updateStrategy.type"
      value = "RollingUpdate"
    },
    {
      name  = "updateStrategy.rollingUpdate.maxUnavailable"
      value = 1
    },
    {
      name  = "updateStrategy.rollingUpdate.maxSurge"
      value = null
    },
    {
      name  = "updateStrategy.rollingUpdate.priorityClassName"
      value = "system-cluster-critical"
    },
    {
      name  = "ingressClass.enabled"
      value = true
    },
    {
      name  = "ingressClass.isDefaultClass"
      value = true
    },
    {
      name  = "ingressRoute.dashboard.enabled"
      value = false
    },
    {
      name  = "providers.kubernetesGateway.enabled"
      value = true
    },
    {
      name  = "providers.kubernetesGateway.experimentalChannel"
      value = true
    },
    {
      name  = "providers.kubernetesCRD.enabled"
      value = true
    },
    {
      name  = "providers.kubernetesCRD.allowCrossNamespace"
      value = true
    },
    {
      name  = "providers.kubernetesCRD.allowExternalNameServices"
      value = true
    },
    {
      name  = "gateway.enabled"
      value = false
    },
    {
      name  = "service.enabled"
      value = false
    },
    {
      name  = "ports.websecure.port"
      value = 443
    },
    {
      name  = "ports.websecure.hostPort"
      value = 443
    },
    {
      name  = "ports.websecure.http.tls.enabled"
      value = true
    },
    {
      name  = "resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "resources.limits.memory"
      value = "256Mi"
    },
    {
      name  = "resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "resources.requests.memory"
      value = "64Mi"
    }
  ]
  values = [yamlencode({
    tolerations = [
      {
        key      = "node-role.kubernetes.io/control-plane"
        operator = "Exists"
        effect   = "NoSchedule"
    }]
    additionalArguments = [
      "--serverstransport.insecureskipverify=true"
    ]
  })]
  depends_on = [kubernetes_namespace_v1.this, null_resource.crds]
}