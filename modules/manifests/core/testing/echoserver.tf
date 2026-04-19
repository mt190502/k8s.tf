## ============================================================================================= ##
#  modules/manifests/core/testing/echoserver.tf                                                   #
## ============================================================================================= ##
resource "kubernetes_daemon_set_v1" "echoserver_daemonset" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "echoserver"
    namespace = kubernetes_namespace_v1.testing_namespace[0].metadata[0].name
    labels = {
      app = "echoserver"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "echoserver"
      }
    }
    template {
      metadata {
        labels = {
          app = "echoserver"
        }
      }
      spec {
        container {
          name  = "echoserver"
          image = "ealen/echo-server:latest"
          port {
            container_port = 80
          }
          env {
            name = "NODENAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
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
  depends_on = [kubernetes_namespace_v1.testing_namespace]
}

resource "kubernetes_service_v1" "echoserver_service" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "echoserver-service"
    namespace = kubernetes_namespace_v1.testing_namespace[0].metadata[0].name
    labels = {
      app = "echoserver"
    }
  }
  spec {
    selector = {
      app = "echoserver"
    }
    port {
      protocol    = "TCP"
      port        = 80
      target_port = 80
    }
    type             = "ClusterIP"
    ip_family_policy = "PreferDualStack"
  }
  depends_on = [kubernetes_daemon_set_v1.echoserver_daemonset]
}

resource "kubernetes_manifest" "echoserver_httproute" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "echoserver-httproute"
      namespace = kubernetes_namespace_v1.testing_namespace[0].metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name      = var.config.gateway_name
          namespace = var.config.gateway_namespace
        }
      ]
      hostnames = [
        "echo.${var.config.domain}"
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = kubernetes_service_v1.echoserver_service[0].metadata[0].name
              port = 80
            }
          ]
        }
      ]
    }
  }
  depends_on = [kubernetes_service_v1.echoserver_service]
}