## ============================================================================================= ##
#  modules/infra/tailscale/post/outputs.tf                                                        #
#                                                                                                 #
#  Outputs for the Tailscale post stage --- device IPs consumed by talos/post and                 #
#  cloudflare/post.                                                                               #
#                                                                                                 #
#    masters   --- Controlplane nodes with their Tailscale device info                            #
#    workers   --- Worker nodes with their Tailscale device info                                  #
#    node_ipv4 --- Node-name -> Tailscale IPv4 (CGNAT 100.64/10 range)                            #
#    node_ipv6 --- Node-name -> Tailscale IPv6 (fd7a::/48 range); empty if not dualstack          #
## ============================================================================================= ##
output "masters" {
  description = "Control plane nodes only, with their Tailscale IP addresses"
  value       = data.tailscale_device.masters
}

output "workers" {
  description = "Worker nodes only, with their Tailscale IP addresses"
  value       = data.tailscale_device.workers
}

output "node_ipv4" {
  description = "Map of node name to Tailscale IPv4 address"
  value = {
    for name, dev in local.all :
    name => try(
      one([
        for a in dev.addresses : a
        if can(cidrcontains("100.64.0.0/10", a)) && cidrcontains("100.64.0.0/10", a)
      ]),
      one([
        for a in dev.addresses : a
        if can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", a))
      ]),
      null,
    )
  }
}

output "node_ipv6" {
  description = "Map of node name to Tailscale IPv6 address"
  value = var.config.dualstack ? {
    for name, dev in local.all :
    name => try(
      one([
        for a in dev.addresses : a
        if can(cidrcontains("fd7a:115c:a1e0::/48", a)) && cidrcontains("fd7a:115c:a1e0::/48", a)
      ]),
      one([
        for a in dev.addresses : a
        if strcontains(a, ":")
      ]),
      null,
    )
  } : {}
}
