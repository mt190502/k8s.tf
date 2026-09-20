## ============================================================================================= ##
#  modules/manifests/core/traefik/ingressclass.tf                                                 #
#                                                                                                 #
#  IngressClass consumed by Traefik's Kubernetes Ingress NGINX provider.                          #
#  Required for Ingress objects using ingressClassName "nginx" - e.g. the Nightscout              #
#  per-device hash routing (upstream-hash-by annotation) for cookie-less clients (AAPS).          #
## ============================================================================================= ##
resource "kubernetes_manifest" "ingress_class_nginx" {
  count = var.enabled ? 1 : 0

  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "IngressClass"
    metadata = {
      name = "nginx"
      labels = {
        "app.kubernetes.io/managed-by" = "traefik"
      }
    }
    spec = {
      controller = "k8s.io/ingress-nginx"
    }
  }
}
