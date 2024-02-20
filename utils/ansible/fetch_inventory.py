# This script fetches the inventory of an enviroment from s3 bucket

import json
import yaml
from minio import Minio
import sys

environment = sys.argv[1]
minioID = sys.argv[2]
minioSecret = sys.argv[3]

INVENTORY_FILENAME="hosts.yml"
ANSIBLE_TARGET_FILENAME="ansible_target.yml"
MINIO_ENDPOINT="cdn.dealer.com.cy"  
# Create client with access and secret key.
client = Minio(MINIO_ENDPOINT, minioID, minioSecret)
# Specify the bucket name
bucket_name = "terraform"

# Fetch hosts.yml file
client.fget_object(bucket_name, environment+"/"+INVENTORY_FILENAME, INVENTORY_FILENAME)
# Fetch ansible-target.yml file
client.fget_object(bucket_name, environment+"/"+ANSIBLE_TARGET_FILENAME, ANSIBLE_TARGET_FILENAME)