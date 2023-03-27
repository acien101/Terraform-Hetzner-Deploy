# Terraform-Hetzner-Deploy

This simple terraform file creates a machine on hertzner, add your public key and gives you the credentials in a format compatible with Ansible.

You need to update the content on the file `example.terraform.tfvars` with your credentials, and change its name to `terraform.tfvars`.

To deploy the machine you need to run:
```
$ terraform init
$ terraform plan -var-file="terraform.tfvars"
$ terraform apply
```
