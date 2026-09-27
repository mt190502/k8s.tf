## ============================================================================================= ##
#  modules/manifests/core/gotify/outputs.tf                                                       #
## ============================================================================================= ##
output "namespace" {
  value = var.enabled ? kubernetes_namespace_v1.this[0].metadata[0].name : null
}

output "bridge_endpoints" {
  value     = var.enabled ? { for k in local.bridge_keys : k => "http://${k}-${var.config.name}-bridge.${kubernetes_namespace_v1.this[0].metadata[0].name}.svc.cluster.local:8080/gotify_webhook" } : {}
  sensitive = true
}

output "discord_adapter_endpoint" {
  value = local.discord_adapter_enabled ? "http://alertmanager-discord-adapter.${kubernetes_namespace_v1.this[0].metadata[0].name}.svc.cluster.local:8080/alertmanager" : ""
}
