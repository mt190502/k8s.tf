## ============================================================================================= ##
#  modules/manifests/core/reflector/helm.tf                                                       #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "reflector"
  repository      = "https://emberstack.github.io/helm-charts"
  chart           = "reflector"
  version         = "10.0.28"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  values = [
    <<-EOF
      cron:
        schedule: "*/15 * * * *"
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
                    app.kubernetes.io/name: reflector
                topologyKey: kubernetes.io/hostname
    EOF
  ]
  depends_on = [kubernetes_namespace_v1.this]
}
