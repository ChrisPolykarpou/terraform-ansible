variable "hcloud_token" {}
variable "ssh_key" {}

# master_count should be an odd number!
variable "master_count" {
  default = 1
}
variable "worker_count" {
  default = 0
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = "${var.hcloud_token}"
}

# Create SSH_KEY
resource "hcloud_ssh_key" "default" {
  name       = "hetzner_key"
  public_key = "${var.ssh_key}"
}

# Create network
resource "hcloud_network" "privNet" {
  name     = "my-net"
  ip_range = "10.98.0.0/16"
  labels = {
    "enviroment" : "production"
  }
}
resource "hcloud_network_subnet" "kubernetes" {
  network_id   = hcloud_network.privNet.id
  type         = "server"
  network_zone = "eu-central"
  ip_range     = "10.98.0.0/16"
}

# Create master node
resource "hcloud_server" "master" {
  count       = var.master_count
  name        = "master-node"
  image       = "ubuntu-22.04"
  labels = {
    "enviroment" : "production"
    "ansible-target" : "true"
  }
  server_type = "cpx21"
  ssh_keys = [hcloud_ssh_key.default.id]
  network {
    network_id = hcloud_network.privNet.id
  }

  # **Note**: the depends_on is important when directly attaching the
  # server to a network. Otherwise Terraform will attempt to create
  # server and sub-network in parallel. This may result in the server
  # creation failing randomly.
  depends_on = [
    hcloud_network_subnet.kubernetes
  ]

  lifecycle {
    ignore_changes = [
      labels
    ]
  }
}

# Worker node resources
resource "hcloud_server" "worker" {
  count       = var.worker_count
  name        = "worker-node-${count.index + 1}"
  image       = "ubuntu-22.04"
  labels = {
    "enviroment" : "production"
    "ansible-target" : "true"
  }
  
  server_type = "cx21"  # Example server type, make configurable
  ssh_keys    = [hcloud_ssh_key.default.id]
  network {
    network_id = hcloud_network.privNet.id
  }
   # **Note**: the depends_on is important when directly attaching the
  # server to a network. Otherwise Terraform will attempt to create
  # server and sub-network in parallel. This may result in the server
  # creation failing randomly.
  depends_on = [
    hcloud_network_subnet.kubernetes
  ]

  lifecycle {
    ignore_changes = [
      labels
    ]
  }
}