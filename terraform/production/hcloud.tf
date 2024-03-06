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
resource "hcloud_ssh_key" "staging" {
  name       = "hetzner_staging_key"
  public_key = "${var.ssh_key}"
}

# Create network
resource "hcloud_network" "privNet-staging" {
  name     = "staging-net"
  ip_range = "10.98.0.0/16"
  labels = {
    "enviroment" : "production"
  }
}
resource "hcloud_network_subnet" "kubernetes-staging" {
  network_id   = hcloud_network.privNet-staging.id
  type         = "server"
  network_zone = var.network_zone
  ip_range     = "10.98.0.0/16"
}

# Create master node
resource "hcloud_server" "master" {
  count       = var.master_count
  name        = "master-node-${count.index + 1}"
  image       = "ubuntu-22.04"
  labels = {
    "enviroment" : "production"
    "ansible-target" : "true"
  }
  server_type = "cx21"
  ssh_keys    = [hcloud_ssh_key.staging.id]
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
  ssh_keys    = [hcloud_ssh_key.staging.id]
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

# KubeAPI Load-balancer
resource "hcloud_load_balancer" "KubeAPI-lb" {
  name               = "staging-kubeAPI-dealerlb"
  load_balancer_type = "lb11"
  location           = "hel1"
}
resource "hcloud_load_balancer_network" "srvnetwork_kubeAPI" {
  load_balancer_id = hcloud_load_balancer.KubeAPI-lb.id
  network_id       = hcloud_network.privNet-staging.id
}
resource "hcloud_load_balancer_service" "lb_service_kubeAPI" {
  load_balancer_id = hcloud_load_balancer.KubeAPI-lb.id
  protocol         = "tcp"
  listen_port      = "6443"
  destination_port = "6443"
}
resource "hcloud_load_balancer_target" "load_balancer_target_control_planes" {
  count            = var.master_count
  type             = "server"
  load_balancer_id = hcloud_load_balancer.KubeAPI-lb.id
  server_id        = hcloud_server.master[count.index].id
}