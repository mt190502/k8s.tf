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
    crd_version = var.versions.crds
  }

  provisioner "local-exec" {
    command = <<-CMD
      helm template traefik-crds oci://ghcr.io/traefik/helm/traefik-crds \
        --version ${self.triggers.crd_version} \
        --set traefik=true \
        --set gatewayAPI=false | kubectl apply --server-side --force-conflicts -f -
    CMD
  }

  depends_on = [kubernetes_namespace_v1.this]
}

resource "helm_release" "this" {
  count           = var.enabled ? 1 : 0
  name            = "traefik"
  repository      = "https://traefik.github.io/charts"
  chart           = "traefik"
  version         = var.versions.main
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  skip_crds       = true
  values = [
    <<-EOF
      deployment:
        kind: DaemonSet
      
      updateStrategy:
        type: RollingUpdate
        rollingUpdate:
          maxUnavailable: 1
          maxSurge: null
      
      priorityClassName: system-cluster-critical
      
      ingressClass:
        enabled: true
        isDefaultClass: true
        
      ingressRoute:
        dashboard:
          enabled: false
      
      providers:
        kubernetesGateway:
          enabled: true
          experimentalChannel: true
        kubernetesCRD:
          enabled: true
          allowCrossNamespace: true
          allowExternalNameServices: true
      
      gateway:
        enabled: false
      
      service:
        enabled: false
      
      ports:
        websecure:
          port: 443
          hostPort: 443
          http:
            tls:
              enabled: true
      
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      
      resources:
        limits:
          cpu: 500m
          memory: 256Mi
        requests:
          cpu: 100m
          memory: 64Mi
      
      additionalArguments:
        - --serverstransport.insecureskipverify=true
    EOF
  ]
  depends_on = [kubernetes_namespace_v1.this, null_resource.crds]
}