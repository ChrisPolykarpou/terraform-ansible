# Python code to extract terraform ip addresses to ansible inventory
import json
import yaml

# Open the terraform.tfstate file for reading
tfstateFile="../terraform/terraform.tfstate"

with open(tfstateFile, 'r') as file:
    data = json.load(file)

ipv4_addresses = []

# Traverse the JSON data and extract ipv4_address values
for resource in data.get('resources', []):
    for instance in resource.get('instances', []):
        attributes = instance.get('attributes', {})
        ipv4_address = attributes.get('ipv4_address')
        if ipv4_address:
            ipv4_addresses.append(ipv4_address)

# Store ip addresses in ansible's inventory
# Read in the file
inventoryFile="../ansible/inventories/prod/hosts.yml"

data = {
    'all': {
        'hosts': {
            'master.dealercy.net': {
                'ansible_user': 'root',
                'ansible_host': ipv4_addresses[0] if ipv4_addresses else None
            }
        },
        'children': {
            'workers': {
                'hosts': {}
            }
        }
    }
}

# Add workers to invenvtory file
for i, ip_address in enumerate(ipv4_addresses[1:], start=1):
    hostname = f'worker{i}.dealercy.net'
    host_data = {
        'ansible_user': 'root',
        'ansible_host': ip_address
    }
    data['all']['children']['workers']['hosts'][hostname] = host_data

with open(inventoryFile, 'w') as yaml_file:
    yaml.dump(data, yaml_file)

