## ============================================================================================= ##
#  modules/manifests/core/tailscale-operator/helm.tf                                              #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "tailscale-operator"
  repository      = "https://pkgs.tailscale.com/helmcharts"
  chart           = "tailscale-operator"
  version         = "1.94.2"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  values = [
    <<-EOF
      operatorConfig:
        defaultTags: "tag:k8s-operator"
      proxyConfig:
        defaultTags: "tag:k8s-pods"
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: tailscale-operator
                topologyKey: kubernetes.io/hostname
    EOF
  ]
  depends_on = [
    kubernetes_secret_v1.operator_oauth,
    kubernetes_secret_v1.tailscale_auth
  ]
}
