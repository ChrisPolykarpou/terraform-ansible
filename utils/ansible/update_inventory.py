# Python code to extract terraform ip addresses and tags to ansible inventory
# First the tfstate file is fetched from our s3 bucket
# Then hosts.yml and ansible_target.yml files are generated

import json
import yaml
from minio import Minio
import copy
import sys

environment = sys.argv[1]
minioID = sys.argv[2]
minioSecret = sys.argv[3]

INVENTORY_FILENAME="hosts.yml"                  
ANSIBLE_TARGET_FILENAME="ansible_target.yml"
MINIO_ENDPOINT="cdn.dealer.com.cy"          # Used to retrieve tfstate
DOMAIN="dealer.com.cy"                      # Used to name hosts for inventoryFile
# Tfstate resource variables
MASTER_NODE_NAME="master"   # Master servers of your TF resource
WORKER_NODE_NAME="worker"   # Worker servers of your tf resource
KUBEAPI_LB="KubeAPI-lb"  # KubeAPI load balancer name resource

# Create client with access and secret key.
client = Minio(MINIO_ENDPOINT, minioID, minioSecret)
# Specify the bucket name and object name
bucket_name = "terraform"
object_name = environment+"/terraform.tfstate"

try:
    # Retrieve tfstate file from s3 bucket
    data = client.get_object(bucket_name, object_name)
    file_data = data.read()
    file_contents = file_data.decode('utf-8')
    
    # Load JSON data
    data = json.loads(file_contents)
except json.JSONDecodeError as err:
    print(f"Error decoding JSON: {err}")
    
ipv4_addresses = []
ipv4_address_names = []
ansible_limit_hostnames = []

# Traverse the JSON data and extract ipv4_address values
for resource in data.get('resources', []):
    for instance in resource.get('instances', []):
        attributes = instance.get('attributes', {})
        # Get IP address
        ipv4_address = attributes.get('ipv4_address')
        if ipv4_address:
            ipv4_addresses.append(ipv4_address)
            ipv4_address_names.append(resource.get('name'))
            # Get ansible tag (if exists)
            ansible_tag = attributes.get('labels')
            if ansible_tag:
                ansible = ansible_tag.get('ansible-target')
                if ansible:
                    ansible_limit_hostnames.append(1)
                else:
                    ansible_limit_hostnames.append(0)
        # Get kubeAPI load-balancer's ip address
        if(resource.get('name') == KUBEAPI_LB):
            ipv4_addresses.append(attributes.get('ipv4'))
            ipv4_address_names.append(resource.get('name'))
            ansible_limit_hostnames.append(0)


# Prepare structure for Ansible's inventory
data = {
    'all': {
        'children': {
            'masters':{
                'hosts': {}
            },
            'workers': {
                'hosts': {}
            }
        }
    }
}
ansible_targetted_data = copy.deepcopy(data)

# Add master and worker nodes to inventory file
count_master=1
count_worker=1
for i, ip_address in enumerate(ipv4_addresses):
    # Master nodes
    if(ipv4_address_names[i] == MASTER_NODE_NAME):
        if(count_master==1):
            hostname = "master-node"
        else:
            hostname = f'{MASTER_NODE_NAME}-{count_master}.{DOMAIN}'
        count_master+=1
        host_data = {
            'ansible_user': 'root',
            'ansible_host': ip_address
        }
        data['all']['children']['masters']['hosts'][hostname] = host_data
        
        # If node is ansible-target
        if ansible_limit_hostnames[i]==1:
            ansible_targetted_data['all']['children']['masters']['hosts'][hostname] = host_data
    
    # Worker nodes
    if(ipv4_address_names[i] == WORKER_NODE_NAME):
        hostname = f'{WORKER_NODE_NAME}-{count_worker}.{DOMAIN}'
        count_worker+=1
        host_data = {
            'ansible_user': 'root',
            'ansible_host': ip_address
        }
        data['all']['children']['workers']['hosts'][hostname] = host_data

        # If node is ansible-target
        if ansible_limit_hostnames[i]==1:
            ansible_targetted_data['all']['children']['workers']['hosts'][hostname] = host_data

    # Add kubeAPI LoadBalancer to variables
    if(ipv4_address_names[i] == KUBEAPI_LB):   
        host_data = {
            'KubeAPI-lb': ip_address
        }    
        data['all']['vars'] = host_data
        ansible_targetted_data['all']['vars'] = host_data

# Generate hosts.yml inventory file
with open(INVENTORY_FILENAME, 'w') as yaml_file:
    yaml.dump(data, yaml_file)
# Generate ansible-target.yml inventory file
with open(ANSIBLE_TARGET_FILENAME, 'w') as yaml_file:
    yaml.dump(ansible_targetted_data, yaml_file)

# Upload hosts.yml file to Minio S3
client.fput_object(bucket_name, environment+"/"+INVENTORY_FILENAME, INVENTORY_FILENAME)



