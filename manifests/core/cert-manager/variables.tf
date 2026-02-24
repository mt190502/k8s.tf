variable "cf_api_token" {
  description = "Cloudflare API token for cert-manager DNS01 challenge"
  type        = string
  sensitive   = true
}