# Combining Ansible and Terraform
Using a single command you can provision and configure kubernetes Cluster in hetzner! By using Terraform and ansible together this makes the whole proccess much easier. There's also a python function (called in bash script) for updating ansible's Inventory before running main playbook.

*create a config.tfvars with your hcloud_token and ssh_key
*This script works only for Ubuntu 22.04 (If you want a different distro or version you need to make adjustments!)
*This can be done cleaner, by setting some vars on how many nodes do you need for your cluster and using loops with terraform instead of reusing the same pattern n-times. (Will do it later)

```
cd scripts
bash init_infrastructure.sh
```