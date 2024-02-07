# Python code to extract terraform ip addresses and tags to ansible inventory
# First the tfstate file is fetched from our s3 bucket
# Then hosts.yml and ansible_target.yml is generated

import json
import yaml
from minio import Minio
import os
import sys

environment = sys.argv[1]
minioID = sys.argv[2]
minioSecret = sys.argv[3]
inventoryFile="hosts.yml"
ansibleTargetFile="ansible_target.yml"

# Create client with access and secret key.
client = Minio("cdn.dealer.com.cy", minioID, minioSecret)
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

# Prepare structure for Ansible's hosts.yml inventory
data = {
    'all': {
        'hosts': {}
        ,
        'children': {
            'workers': {
                'hosts': {}
            }
        }
    }
}

# GENERATE generic hosts.yml file
# Add master and worker nodes to inventory file
count_master=1
count_worker=1
for i, ip_address in enumerate(ipv4_addresses):
    # Master nodes
    if(ipv4_address_names[i] == 'master'):
        hostname = f'master-{count_master}.dealer.com.cy'
        count_master+=1
        host_data = {
            'ansible_user': 'root',
            'ansible_host': ip_address
        }
        data['all']['hosts'][hostname] = host_data
    # Worker nodes
    if(ipv4_address_names[i] == 'worker'):
        hostname = f'worker-{count_worker}.dealer.com.cy'
        count_worker+=1
        host_data = {
            'ansible_user': 'root',
            'ansible_host': ip_address
        }
        data['all']['children']['workers']['hosts'][hostname] = host_data

# Generate hosts.yml inventory file
with open(inventoryFile, 'w') as yaml_file:
    yaml.dump(data, yaml_file)

data = {
    'all': {
        'hosts': {}
        ,
        'children': {
            'workers': {
                'hosts': {}
            }
        }
    }
}
# GENERATE ansible-targeted ansible-target.yml file
# Add master and worker nodes to inventory file
count_master=1
count_worker=1
for i, ip_address in enumerate(ipv4_addresses):
    if ansible_limit_hostnames[i]==1:
        # Master nodes
        if(ipv4_address_names[i] == 'master'):
            hostname = f'master-{count_master}.dealer.com.cy'
            count_master+=1
            host_data = {
                'ansible_user': 'root',
                'ansible_host': ip_address
            }
            data['all']['hosts'][hostname] = host_data
        # Worker nodes
        if(ipv4_address_names[i] == 'worker'):
            hostname = f'worker-{count_worker}.dealer.com.cy'
            count_worker+=1
            host_data = {
                'ansible_user': 'root',
                'ansible_host': ip_address
            }
            data['all']['children']['workers']['hosts'][hostname] = host_data

# Generate ansible-target.yml inventory file
with open(ansibleTargetFile, 'w') as yaml_file:
    yaml.dump(data, yaml_file)

# Upload files to Minio S3
client.fput_object(bucket_name, environment+"/"+inventoryFile, inventoryFile)
# client.fput_object(bucket_name, environment+"/"+ansibleTargetFile, ansibleTargetFile)

# Clean up
# os.remove('hosts.yml')
    



