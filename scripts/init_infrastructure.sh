# Change according to your folder structure
terraform_dir=../terraform
scripts_dir=../scripts
ansible_dir=../ansible
# Provisioning with terraform
cd $terraform_dir
terraform apply -var-file=config.tfvars -auto-approve

# Updating inventory using python
echo "Updating ansible inventory with newly provisioned servers"
cd $scripts_dir
python3 update_inventory.py

# Run ansible
cd $ansible_dir
ansible-playbook -i inventories/prod/hosts.yml roles/common/tasks/main.yaml

