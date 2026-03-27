## ============================================================================================= ##
#  modules/manifests/core/psmdb-operator/helm.tf                                                  #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "psmdb-operator"
  repository      = "https://percona.github.io/percona-helm-charts"
  chart           = "psmdb-operator"
  version         = var.chart_version
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  values = [
    <<-EOF
      watchAllNamespaces: true
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
                    app.kubernetes.io/name: psmdb-operator
                topologyKey: kubernetes.io/hostname
    EOF
  ]
  depends_on = [kubernetes_namespace_v1.this]
}
