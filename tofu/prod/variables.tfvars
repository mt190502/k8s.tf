//////////////////////////////////////////////////
//
//// Provider Configuration
//
//////////////////////////////////////////////////
talos = {
  version = "v1.12.4"
  images = {
    amd64 = { id = "358263593", code = "cx33" }
    arm64 = { id = "358263592", code = "cax11" }
  }
  options = {
    dualstack = true
    kubespan  = false
    kubeprism = true
  }
}


//////////////////////////////////////////////////
//
//// Cluster Configuration
//
/////////////////////////////////////////////////
cluster = {
  name    = "srv.mtaha.dev"
  version = "v1.35.1"
  url = {
    dns       = "mtaha.dev"
    main      = "srv.mtaha.dev"
    apiserver = "k8s.srv.mtaha.dev"
  }
  ipcfg = {
    pod_cidr = {
      ipv4 = "10.244.0.0/16"
      ipv6 = "2001:db8:42:0::/56"
    }
    service_cidr = {
      ipv4 = "10.96.0.0/12"
      ipv6 = "2001:db8:42:1::/112"
    }
  }
  nodes = {
    masters = [
      {
        name     = "m1"
        type     = "arm64"
        location = "hel1"
        taints   = []
      }
    ]
    workers = [
      {
        name     = "w1"
        type     = "amd64"
        location = "hel1"
        taints   = []
      },
      {
        name     = "w2"
        type     = "amd64"
        location = "hel1"
        taints   = []
      }
    ]
  }
  firewall = {
    enabled = true
    rules = [
      {
        short_name  = "https-in"
        description = "Allow HTTPS traffic",
        protocol    = "tcp",
        direction   = "in",
        port        = "443",
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
      },
      {
        short_name  = "https-in-udp"
        description = "Allow HTTPS traffic",
        protocol    = "udp",
        direction   = "in",
        port        = "443",
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
      },
      {
        short_name  = "nodeport-tcp"
        description = "Allow Kubernetes NodePort TCP range",
        protocol    = "tcp",
        direction   = "in",
        port        = "30000-32767",
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
      },
      {
        short_name  = "nodeport-udp"
        description = "Allow Kubernetes NodePort UDP range",
        protocol    = "udp",
        direction   = "in",
        port        = "30000-32767",
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
      },
      {
        short_name  = "tailscale"
        description = "Allow Tailscale traffic",
        protocol    = "udp",
        direction   = "in",
        port        = "41641",
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
      },
      {
        short_name  = "wireguard"
        description = "Allow pod2pod WireGuard traffic",
        protocol    = "udp",
        direction   = "in",
        port        = "51871",
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
      },
      {
        short_name  = "cilium-vxlan"
        description = "Allow Cilium VXLAN tunnel traffic",
        protocol    = "udp",
        direction   = "in",
        port        = "8472",
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
      }
    ]
  }
}