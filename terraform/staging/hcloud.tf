variable "hcloud_token" {}
variable "ssh_key" {}
# master_count should be an odd number!
# For HA cluster you need at least 3 stacked control-plane or decoupled external etcd and control-plane nodes.
# Thus a load-balancer is needed to expose the Kube-apiserver. 
# AT THE MOMENT THIS IS NOT SUPPORTED! 
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

# Load-balancer
resource "hcloud_load_balancer" "load_balancer" {
  name               = "staging-dealerlb"
  load_balancer_type = "lb11"
  location           = "hel1"
}
resource "hcloud_load_balancer_network" "srvnetwork" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  network_id       = hcloud_network.privNet-staging.id
}
resource "hcloud_load_balancer_service" "lb_service" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "tcp"
  listen_port      = "80"
  destination_port = "32080"
}
resource "hcloud_load_balancer_service" "lb_service2" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  protocol         = "tcp"
  listen_port      = "443"
  destination_port = "32443"
}
resource "hcloud_load_balancer_target" "load_balancer_target_worker" {
  count            = var.worker_count
  type             = "server"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  server_id        = hcloud_server.worker[count.index].id
}
