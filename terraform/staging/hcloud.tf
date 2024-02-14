variable "hcloud_token" {}
variable "ssh_key" {}
variable "master_count" {}
variable "worker_count" {}
variable "server_type_master" {}
variable "server_type_worker" {}
variable "network_zone" {}

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
  name     = "production-net"
  ip_range = "10.98.0.0/20"
  labels = {
    "enviroment" : "production"
  }
}
resource "hcloud_network_subnet" "kubernetes" {
  network_id   = hcloud_network.privNet.id
  type         = "server"
  network_zone = var.network_zone
  ip_range     = "10.98.0.0/20"
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
    prevent_destroy = true
    ignore_changes = [
      labels,
      ssh_keys
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

# Application Load-balancer
resource "hcloud_load_balancer" "load_balancer" {
  name               = "dealerlb"
  load_balancer_type = "lb11"
  location           = "hel1"
  delete_protection  = "true"

  lifecycle {
    prevent_destroy = true
  }
}
resource "hcloud_load_balancer_network" "srvnetwork" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  network_id       = hcloud_network.privNet.id
}
resource "hcloud_load_balancer_service" "lb_service" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "tcp"
  listen_port      = "80"
  destination_port = "32080"

  lifecycle {
    prevent_destroy = true
  }
}
resource "hcloud_load_balancer_service" "lb_service2" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "tcp"
  listen_port      = "443"
  destination_port = "32443"

  lifecycle {
    prevent_destroy = true
  }
}
resource "hcloud_load_balancer_target" "load_balancer_target_worker" {
  count            = var.worker_count
  type             = "server"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  server_id        = hcloud_server.worker[count.index].id
}