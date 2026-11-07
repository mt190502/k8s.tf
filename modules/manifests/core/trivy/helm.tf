## ============================================================================================= ##
#  modules/manifests/core/trivy/helm.tf                                                           #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "trivy-operator"
  repository      = "https://aquasecurity.github.io/helm-charts"
  chart           = "trivy-operator"
  version         = "0.38.1"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  set = [
    { name = "operator.builtInTrivyServer", value = var.config.built_in_trivy_server, },
    { name = "operator.metricsVulnIdEnabled", value = true, },
    { name = "operator.scanJobsConcurrentLimit", value = var.config.scan_jobs_concurrent_limit, },
    { name = "operator.scannerReportTTL", value = var.config.scan_report_ttl, },
    { name = "resources.limits.memory", value = "512Mi", },
    { name = "resources.requests.cpu", value = "50m", },
    { name = "resources.requests.memory", value = "128Mi", },
    { name = "serviceMonitor.enabled", value = true, },
    { name = "trivy.ignoreUnfixed", value = var.config.ignore_unfixed, },
    { name = "trivy.resources.limits.memory", value = "512Mi", },
    { name = "trivy.resources.requests.cpu", value = "100m", },
    { name = "trivy.resources.requests.memory", value = "128Mi", }
  ]
  values = [yamlencode({
    trivyOperator = {
      scanJobAffinity = {
        podAntiAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchLabels = { "app.kubernetes.io/managed-by" = "trivy-operator" }
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }
          ]
        }
      }
    }
    compliance = {
      specs = [
        "k8s-pss-baseline-0.1",
        "k8s-pss-restricted-0.1",
      ]
    }
    excludeNamespaces = join(",", var.config.exclude_namespaces)
    nodeCollector = {
      tolerations = [
        { operator = "Exists" }
      ]
      volumeMounts = [
        { name = "var-lib-kubelet", mountPath = "/var/lib/kubelet", readOnly = true },
        { name = "etc-kubernetes", mountPath = "/etc/kubernetes", readOnly = true },
        { name = "etc-cni-netd", mountPath = "/etc/cni/net.d/", readOnly = true },
      ]
      volumes = [
        { name = "var-lib-kubelet", hostPath = { path = "/var/lib/kubelet" } },
        { name = "etc-kubernetes", hostPath = { path = "/etc/kubernetes" } },
        { name = "etc-cni-netd", hostPath = { path = "/etc/cni/net.d/" } },
      ]
    }
    trivy = {
      severity = var.config.severity
    }
  })]
  depends_on = [kubernetes_namespace_v1.this]
}
