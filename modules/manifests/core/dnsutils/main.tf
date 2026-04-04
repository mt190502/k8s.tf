## ============================================================================================= ##
#  modules/manifests/core/testing/dnsutils.tf                                                        #
## ============================================================================================= ##
resource "kubernetes_daemon_set_v1" "dnsutils_daemonset" {
  metadata {
    name      = "dnsutils"
    labels = {
      app = "dnsutils"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "dnsutils"
      }
    }
    template {
      metadata {
        labels = {
          app = "dnsutils"
        }
      }
      spec {
        container {
          name  = "dnsutils"
          image = "registry.k8s.io/e2e-test-images/agnhost:2.61"
          command = ["sleep", "infinity"]
        }
        toleration {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
        toleration {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      }
    }
  }
}