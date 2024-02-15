# Infrastructure Pipelines
A way of using terraform and ansible together in a fully automated IaC way using Github-Actions. This allows scaling up and down, building and destroying Kubernetes Clusters.

I am using Hetzner Cloud but you can switch to any provider you like by modifying the terraform code. Another possibility is writing terraform code for different cloud-providers in order to remain as cloud-agnostic as possible 

[Tfstate](https://developer.hashicorp.com/terraform/language/state) file for each environment is stored in self-hosted minio-s3 storage. 
> It is recommended to use a [lock](https://developer.hashicorp.com/terraform/language/state/locking) for your state!

```
# Required Github-Secrets
HCLOUD_TOKEN
MINIO_ACCESS_KEY
MINIO_SECRET_KEY
SSH_PRIVATE_KEY
```

For [HA-cluster](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology) you need at least 3 __stacked control-plane__ **or** decoupled __external etcd + control-plane nodes__. Thus a load-balancer is needed to expose the Kube-apiserver.

### Additional variables in utils/ansible/update_inventory.py
Terraform's resource variables should match the following tfstate variables!

```
INVENTORY_FILENAME="hosts.yml"                  
ANSIBLE_TARGET_FILENAME="ansible_target.yml"
MINIO_ENDPOINT="cdn.dealer.com.cy"          # Used to retrieve tfstate
DOMAIN="dealer.com.cy"                      # Used to name hosts for inventoryFile
# Tfstate resource variables
MASTER_NODE_NAME="master"   # Master servers of your TF resource
WORKER_NODE_NAME="worker"   # Worker servers of your tf resource
KUBEAPI_LB="KubeAPI-lb"  # KubeAPI load balancer name resource
```

### Terraform's Backend
Below you can see the configuration of Terraform's Backend. The file is located at terraform/ENVIROMENT/config.tf
```
# Configure terraform to use s3 minio
backend "s3" {
    bucket = "terraform"
    key = "staging/terraform.tfstate"
    endpoints = {
        s3 = "https://cdn.dealer.com.cy"   # Minio endpoint
    }

    access_key = "MINIO_ACCESS_KEY"
    secret_key = "MINIO_SECRET_KEY"

    region = "main"
    skip_requesting_account_id = true
    skip_credentials_validation = true
    skip_metadata_api_check = true
    skip_region_validation = true
    use_path_style = true
}
```

## Provision-infra.yml
This pipeline builds an enviroment based on terraform configuration. The pipeline takes __**Enviroment**__ as an argument.

## ansible.yml
This pipeline configures hosts to a fully functioning Kubernetes Cluster or Scales up by applying configurations only to the newly created and unconfigured machines. The pipeline takes __**Enviroment**__ as an argument.

The inventory file is generated by a python script dynamically following tfstate as a **single source of truth**. For highlighting the machines that ansible needs to target i used a tag __"**ansible-target**"__ in terraform's tfstate file so that i can generate a different inventory for the newly created instances. The ansible-target tags get wiped out by the pipeline when the machines are part of the Cluster.

## destory-infra.yml
This pipeline completely destroys an enviroment. The pipeline takes __**Enviroment**__ as an argument.