resource "kubernetes_config_map_v1" "configmap" {
  count = var.enabled ? 1 : 0
  metadata {
    name      = "${var.config.name}-config"
    namespace = kubernetes_namespace_v1.this[0].metadata[0].name
  }
  data = {
    "auth.conf" = <<-EOT
      [auth]
      cache_failed_logins_expiry = 90
      cache_logins = false
      cache_successful_logins_expiry = 15
      delay = 1
      htpasswd_cache = false
      htpasswd_encryption = autodetect
      htpasswd_filename = /app/data/users
      realm = Radicale - Password Required
      strip_domain = false
      type = htpasswd
    EOT

    "encoding.conf" = <<-EOT
      [encoding]
      request = utf-8
      stock = utf-8
    EOT

    "logging.conf" = <<-EOT
      [logging]
      backtrace_on_debug = false
      bad_put_request_content = false
      level = info
      mask_passwords = false
      request_content_on_debug = false
      request_header_on_debug = false
      response_content_on_debug = false
      rights_rule_doesnt_match_on_debug = false
      storage_cache_actions_on_debug = false
    EOT

    "reporting.conf" = <<-EOT
      [reporting]
      max_freebusy_occurrence = 10000
    EOT

    "server.conf" = <<-EOT
      [server]
      hosts = 0.0.0.0:5232
      max_connections = 8
      max_content_length = 100000000
      ssl = true
      certificate = /app/ssl/tls.crt
      key = /app/ssl/tls.key
      timeout = 30
    EOT

    "storage.conf" = <<-EOT
      [storage]
      filesystem_cache_folder = /app/data/cache
      filesystem_folder = /app/data/collections
      hook = false
      max_sync_token_age = 2592000
      predefined_collections = 
      skip_broken_item = true
      type = multifilesystem
      use_cache_subfolder_for_history = false
      use_cache_subfolder_for_item = false
      use_cache_subfolder_for_synctoken = false
      use_mtime_and_size_for_item_cache = false
    EOT

    "web.conf" = <<-EOT
      [web]
      type = internal
    EOT
  }
  depends_on = [kubernetes_namespace_v1.this]
}