# Infrastructure Pipelines

[Tfstate](https://developer.hashicorp.com/terraform/language/state) file for each environment is stored in minio-s3 storage. It is recommended to use a [lock](https://developer.hashicorp.com/terraform/language/state/locking) for your state!

## Provision-infra.yml
This pipeline builds an enviroment based on terraform configuration. The pipeline takes enviroment as an argument.

## destory-infra.yml
This pipeline completely destroys an enviroment. The pipeline takes enviroment as an argument.