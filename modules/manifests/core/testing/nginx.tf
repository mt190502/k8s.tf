## ============================================================================================= ##
#  modules/manifests/core/testing/nginx.tf                                                        #
## ============================================================================================= ##
resource "kubernetes_daemon_set_v1" "nginx_daemonset" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace_v1.testing_namespace[0].metadata[0].name
    labels = {
      app = "nginx"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port {
            container_port = 80
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

resource "kubernetes_service_v1" "nginx_service" {
  count = var.enabled ? 1 : 0  
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace_v1.testing_namespace[0].metadata[0].name
    labels = {
      app = "nginx"
    }
  }
  spec {
    selector = {
      app = "nginx"
    }
    port {
      protocol    = "TCP"
      port        = 80
      target_port = 80
    }
    type             = "ClusterIP"
    ip_family_policy = "PreferDualStack"
  }
  depends_on = [kubernetes_daemon_set_v1.nginx_daemonset]
}

resource "kubernetes_manifest" "nginx_httproute" {
  count = var.enabled ? 1 : 0
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "nginx-httproute"
      namespace = kubernetes_namespace_v1.testing_namespace[0].metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name      = var.config.gateway_name
          namespace = var.config.namespace
        }
      ]
      hostnames = [
        "nginx.${var.config.domain}"
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
              name = kubernetes_service_v1.nginx_service[0].metadata[0].name
              port = 80
            }
          ]
        }
      ]
    }
  }
  depends_on = [kubernetes_service_v1.nginx_service]
}