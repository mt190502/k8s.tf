## ============================================================================================= ##
#  modules/manifests/core/trivy/prometheusrule.tf                                                 #
## ============================================================================================= ##
resource "kubernetes_manifest" "prometheus_rule" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "trivy-alerts"
      namespace = kubernetes_namespace_v1.this.metadata[0].name
      labels = {
        "app.kubernetes.io/part-of" = helm_release.this.name
      }
    }
    spec = {
      groups = [
        {
          name = "trivy.rules"
          rules = [
            {
              alert = "TrivyOperatorDown"
              expr  = "up{namespace=\"trivy-system\", job=\"trivy-operator\"} == 0"
              "for" = "10m"
              labels = {
                severity  = "critical"
                component = "trivy"
              }
              annotations = {
                summary     = "Trivy Operator is unreachable"
                description = "Prometheus cannot scrape the trivy-operator on {{ $labels.instance }}; vulnerability scanning is stalled."
              }
            },
            {
              alert = "TrivyScanJobsFailing"
              expr  = "sum(increase(kube_job_status_failed{namespace=\"trivy-system\", job_name=~\"scan-.*\"}[30m])) > 3"
              "for" = "10m"
              labels = {
                severity  = "warning"
                component = "trivy"
              }
              annotations = {
                summary     = "Trivy scan jobs are failing"
                description = "{{ $value }} trivy scan jobs failed in the last 30 minutes; check the operator logs and node-collector admission."
              }
            },
            {
              alert = "TrivyImageCriticalVulnerabilities"
              expr  = "trivy_image_vulnerabilities{severity=\"Critical\"} > 20"
              "for" = "1h"
              labels = {
                severity  = "warning"
                component = "trivy"
              }
              annotations = {
                summary     = "Image with more than 20 critical vulnerabilities"
                description = "{{ $labels.image_repository }}:{{ $labels.image_tag }} ({{ $labels.resource_namespace }}/{{ $labels.resource_name }}) carries {{ $value }} unpatched critical vulnerabilities."
              }
            },
            {
              alert = "TrivyExposedSecretsCritical"
              expr  = "trivy_image_exposedsecrets{severity=\"Critical\"} > 0"
              "for" = "30m"
              labels = {
                severity  = "critical"
                component = "trivy"
              }
              annotations = {
                summary     = "Critical secret exposed in an image"
                description = "{{ $labels.image_repository }}:{{ $labels.image_tag }} ({{ $labels.resource_namespace }}/{{ $labels.resource_name }}) contains a critical-severity secret; rotate and rebuild."
              }
            }
          ]
        }
      ]
    }
  }
}
