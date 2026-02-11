//////////////////////////////////////////////////
//
//// Provider Configuration
//
//////////////////////////////////////////////////
talos = {
  version = "v1.12.2"
  images = {
    amd64 = { id = "356499561", code = "cx33" }
    arm64 = { id = "356499560", code = "cax11" }
  }
}


//////////////////////////////////////////////////
//
//// Cluster Configuration
//
/////////////////////////////////////////////////
cluster = {
  name    = "srv-test.mtaha.dev"
  version = "v1.34.3"
  url = {
    main = "srv-test.mtaha.dev"
    prefixes = {
      api      = "k8s"
      external = "lb"
      internal = "int"
    }
  }
  nodes = {
    masters = [
      {
        name     = "m1-test"
        type     = "arm64"
        location = "fsn1"
        taints   = []
      },
      {
        name     = "m2-test"
        type     = "arm64"
        location = "hel1"
        taints   = []
      }
    ]
    workers = [
      {
        name     = "w1-test"
        type     = "amd64"
        location = "nbg1"
        taints   = []
      },
      {
        name     = "w2-test"
        type     = "amd64"
        location = "fsn1"
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
        type        = "both",
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
        type        = "both",
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
        type        = "both",
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
        type        = "both",
        source_ips = [
          "0.0.0.0/0",
          "::/0"
        ]
      }
    ]
  }
}