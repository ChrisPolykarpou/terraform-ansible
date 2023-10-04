# Set the variable value in *.tfvars file
# or using the -var="hcloud_token=..." CLI option
variable "hcloud_token" {}
variable "ssh_key" {}

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
}
resource "hcloud_network_subnet" "kubernetes" {
  network_id   = hcloud_network.privNet.id
  type         = "server"
  network_zone = "eu-central"
  ip_range     = "10.98.0.0/16"
}

# Create master node
resource "hcloud_server" "master" {
  name        = "master-node"
  image       = "ubuntu-22.04"
  server_type = "cx11"
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
}

# Create volume
resource "hcloud_volume" "storage-master" {
  name       = "master-volume"
  size       = 50
  server_id  = "${hcloud_server.master.id}"
  automount  = true
  format     = "ext4"
}

# Create worker node
resource "hcloud_server" "worker1" {
  name        = "worker1-node"
  image       = "ubuntu-22.04"
  server_type = "cx21"
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
}

# Create volume (worker node)
resource "hcloud_volume" "storage-worker1" {
  name       = "worker1-volume"
  size       = 50
  server_id  = "${hcloud_server.worker1.id}"
  automount  = true
  format     = "ext4"
}

resource "hcloud_floating_ip" "master" {
  type      = "ipv4"
  home_location = "nbg1"
}
