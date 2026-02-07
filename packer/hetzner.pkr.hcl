//////////////////////////////////////////////////
//
//// Infrastructure: Hetzner Talos
//
//////////////////////////////////////////////////
#~ Packer configuration for Hetzner Talos cluster
packer {
  required_plugins {
    hetzner = {
      version = "~> v1.7.1"
      source  = "github.com/hetznercloud/hcloud"
    }
  }
}

locals {
  labels = {
    type    = "infra"
    os      = "talos"
    version = var.talos_version
  }
}

#~ Generate the rescue snapshots (one per architecture, reused for all nodes of that role)
source "hcloud" "talos_amd64" {
  rescue        = "linux64"
  image         = "debian-12"
  location      = var.server_location
  server_type   = var.server_types.amd64
  ssh_username  = "root"
  token         = var.hetzner_token
  snapshot_name = "amd64/${var.talos_version}"
  snapshot_labels = merge(local.labels, {
    architecture = "amd64"
  })
}
source "hcloud" "talos_arm64" {
  rescue        = "linux64"
  image         = "debian-12"
  location      = var.server_location
  server_type   = var.server_types.arm64
  ssh_username  = "root"
  token         = var.hetzner_token
  snapshot_name = "arm64/${var.talos_version}"
  snapshot_labels = merge(local.labels, {
    architecture = "arm64"
  })
}

#~ Build the Talos OS images (once per architecture, reused for all nodes of that role)
build {
  name = "talos-${var.talos_version}"
  sources = [
    "source.hcloud.talos_amd64",
    "source.hcloud.talos_arm64"
  ]

  provisioner "shell" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "echo 'Building Talos OS image...';",
      "apt-get update -y",
      "apt-get install -y wget xz-utils",
      "ARCH=\"$(uname -m)\"",
      "case \"$ARCH\" in x86_64) TALOS_ARCH=amd64 ;; aarch64|arm64) TALOS_ARCH=arm64 ;; *) echo \"Unsupported arch: $ARCH\"; exit 1 ;; esac",
      "echo \"Detected arch: $ARCH -> $TALOS_ARCH\"",
      "wget -qO /tmp/talos.raw.xz https://factory.talos.dev/image/${var.talos_image_id}/${var.talos_version}/hcloud-$${TALOS_ARCH}.raw.xz",
      "xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda bs=4M status=progress oflag=sync"
    ]
  }
}
