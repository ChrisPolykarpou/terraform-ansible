# master_count should be an odd number!
# For HA cluster you need at least 3 stacked control-plane or decoupled external etcd and control-plane nodes.
# Thus a load-balancer is needed to expose the Kube-apiserver. 
# Currently only stacked control-plane nodes are supported!
master_count = 1
worker_count = 2
# Server types for nodes
server_type_master = "cpx21"
server_type_worker = "cx21"
# network
network_zone = "eu-central"
