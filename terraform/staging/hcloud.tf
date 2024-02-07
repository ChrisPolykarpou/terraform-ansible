variable "hcloud_token" {}
variable "ssh_key" {}
# master_count should be an odd number!
variable "master_count" {
  default = 1
}
variable "worker_count" {
  default = 2
}

# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = "${var.hcloud_token}"
}

# Create SSH_KEY 
# (UNCOMMENT THIS IF YOU ARE USING A DIFFERENT KEY).
# resource "hcloud_ssh_key" "staging" {
#   name       = "hetzner_staging_key"
#  public_key = "${var.ssh_key}"
# }

# Create network
resource "hcloud_network" "privNet-staging" {
  name     = "staging-net"
  ip_range = "10.98.0.0/16"
  labels = {
    "enviroment" : "staging"
  }
}
resource "hcloud_network_subnet" "kubernetes-staging" {
  network_id   = hcloud_network.privNet-staging.id
  type         = "server"
  network_zone = "eu-central"
  ip_range     = "10.98.0.0/16"
}

# Create master node
resource "hcloud_server" "master" {
  count       = var.master_count
  name        = "master-node-${count.index + 1}"
  image       = "ubuntu-22.04"
  labels = {
    "enviroment" : "staging"
    "ansible-target" : "true"
  }
  server_type = "cx21"
  ssh_keys    = [15344323]
  network {
    network_id = hcloud_network.privNet-staging.id
  }

  # **Note**: the depends_on is important when directly attaching the
  # server to a network. Otherwise Terraform will attempt to create
  # server and sub-network in parallel. This may result in the server
  # creation failing randomly.
  depends_on = [
    hcloud_network_subnet.kubernetes-staging
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
    "enviroment" : "staging"
    "ansible-target" : "true"
  }
  server_type = "cx21"  # Example server type, make configurable
  ssh_keys    = [15344323]
  network {
    network_id = hcloud_network.privNet-staging.id
  }
  # **Note**: the depends_on is important when directly attaching the
  # server to a network. Otherwise Terraform will attempt to create
  # server and sub-network in parallel. This may result in the server
  # creation failing randomly.
  depends_on = [
    hcloud_network_subnet.kubernetes-staging
  ]

  lifecycle {
    ignore_changes = [
      labels
    ]
  }
}
