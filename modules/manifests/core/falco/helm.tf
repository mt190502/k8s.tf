## ============================================================================================= ##
#  modules/manifests/core/falco/helm.tf                                                           #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "falco"
  repository      = "https://falcosecurity.github.io/charts"
  chart           = "falco"
  version         = "9.2.2"
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  upgrade_install = true
  set = [
    { name = "controller.kind", value = "daemonset", },
    { name = "driver.kind", value = "modern_ebpf", },
    { name = "driver.modernEbpf.leastPrivileged", value = false, },
    { name = "falcoctl.artifact.follow.resources.limits.memory", value = "64Mi", },
    { name = "falcoctl.artifact.follow.resources.requests.cpu", value = "10m", },
    { name = "falcoctl.artifact.follow.resources.requests.memory", value = "32Mi", },
    { name = "falcoctl.artifact.install.resources.limits.memory", value = "64Mi", },
    { name = "falcoctl.artifact.install.resources.requests.cpu", value = "10m", },
    { name = "falcoctl.artifact.install.resources.requests.memory", value = "32Mi", },
    { name = "falcosidekick.enabled", value = var.config.falcosidekick_enabled, },
    { name = "falcosidekick.replicaCount", value = 1, },
    { name = "falcosidekick.resources.limits.memory", value = "256Mi", },
    { name = "falcosidekick.resources.requests.cpu", value = "10m", },
    { name = "falcosidekick.resources.requests.memory", value = "128Mi", },
    { name = "falcosidekick.serviceMonitor.enabled", value = true, },
    { name = "falcosidekick.webui.enabled", value = false, },
    { name = "grafana.dashboards.configMaps.falco.namespace", value = var.config.kps_namespace, },
    { name = "grafana.dashboards.enabled", value = true, },
    { name = "metrics.enabled", value = true, },
    { name = "resources.limits.memory", value = "512Mi", },
    { name = "resources.requests.cpu", value = "100m", },
    { name = "resources.requests.memory", value = "256Mi", },
    { name = "serviceMonitor.create", value = true, },
    { name = "tty", value = true, }
  ]
  values = [yamlencode({
    collectors = {
      containerEngine = {
        engines = {
          docker      = { enabled = false }
          podman      = { enabled = false }
          containerd  = { enabled = false }
          cri         = { enabled = true, sockets = ["/run/containerd/containerd.sock"] }
          lxc         = { enabled = false }
          libvirt_lxc = { enabled = false }
          bpm         = { enabled = false }
        }
      }
    }
    falcosidekick = {
      config = {
        alertmanager = {
          hostport          = "http://kube-prometheus-stack-alertmanager.${var.config.kps_namespace}.svc.cluster.local:9093"
          endpoint          = "/api/v2/alerts"
          minimumpriority   = var.config.minimum_priority
          expireafter       = "300"
          extralabels       = "alertname:Falco,namespace:falco"
          customseveritymap = "emergency:critical,alert:critical,critical:critical,error:warning,warning:warning,notice:info,informational:info,debug:info"
        }
      }
    }
    tolerations = [
      { operator = "Exists" }
    ]
  })]
  depends_on = [kubernetes_namespace_v1.this]
}
