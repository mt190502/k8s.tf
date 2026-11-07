## ============================================================================================= ##
#  modules/manifests/core/falco/exceptions.tf                                                     #
#                                                                                                 #
#  Falco rule exceptions for workloads that download and run third-party binaries by design.      #
#  Rendered into a ConfigMap mounted at /etc/falco/rules.d, the last entry of falco.rules_files,   #
#  so the overrides are applied on top of the upstream ruleset.                                   #
#                                                                                                 #
#  Why: the Atlantis IaC runner installs packages and fetches tofu/kubectl/terragrunt/sops/jq     #
#  inside its init container on every pod start and then talks to the API server. Reporting that  #
#  as a runtime threat buries the real alerts (one pod start produced ~127 Critical events).      #
## ============================================================================================= ##
locals {
  exception_rules = [
    for rule in [
      "Drop and execute new binary in container",
      "Contact K8S API Server From Container",
      ] : {
      rule     = rule
      override = { exceptions = "append" }
      exceptions = [
        for ns in var.config.toolchain_namespaces : {
          name   = "toolchain_bootstrap_${replace(ns, "-", "_")}"
          fields = ["k8s.ns.name"]
          comps  = ["="]
          values = [[ns]]
        }
      ]
    }
  ]
}

resource "kubernetes_config_map_v1" "exceptions" {
  metadata {
    name      = "falco-exceptions"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  data = {
    "falco-exceptions.yaml" = yamlencode(local.exception_rules)
  }
  depends_on = [kubernetes_namespace_v1.this]
}
