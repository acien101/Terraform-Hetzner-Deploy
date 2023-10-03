############## Variables ###############

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.31.1"
    }
  }
}

# Generate a ECDSA key pair for root user
resource "tls_private_key" "ssh_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

# hetzner cloud token
variable "hcloud_token" {
  sensitive = true # Requires terraform >= 0.14
}

# User name on the remote machine
variable "user_uid_1000"{
  type = string
  default = "delta"
}

# Pass on the remote machine
variable "pass_uid_1000"{
  sensitive = true
  default = "changeme"
}

# Path of the local public key uploaded to remote system
variable "public_key_path"{
  type = string
  sensitive = true
}

# Upload your public ssh key on Hetzner cloud
resource "hcloud_ssh_key" "default" {
  name       = "facien@apu"
  public_key = file("${var.public_key_path}")
}

# Upload the generated root public ssh key on Hetzner cloud
resource "hcloud_ssh_key" "terraform" {
  name = "terraform"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Define Hetzner provider
provider "hcloud" {
  token = var.hcloud_token
}

# Create an Ubuntu 20.04 server
resource "hcloud_server" "ubuntu20" {
  name = "ubuntu20"
  image = "ubuntu-20.04"
  server_type = "cx21"
  ssh_keys  = ["${hcloud_ssh_key.default.id}",
               "${hcloud_ssh_key.terraform.id}"]

  # Refresh local ECDSA host key
  provisioner "local-exec" {
    command = "ssh-keygen -f \"/home/facien/.ssh/known_hosts\" -R \"${self.ipv4_address}\""
  }

  # Create a new user on remote machine
  # and add the key to remote machine
  provisioner "remote-exec" {
    inline = [
      "useradd -m -p $(openssl passwd -1 ${var.pass_uid_1000}) ${var.user_uid_1000}",
      "usermod -aG sudo ${var.user_uid_1000}",
      "sudo -u ${var.user_uid_1000} mkdir -m 755 /home/${var.user_uid_1000}/.ssh",
      "sudo -u ${var.user_uid_1000} touch /home/${var.user_uid_1000}/.ssh/authorized_keys",
      "sudo -u ${var.user_uid_1000} printf \"${hcloud_ssh_key.default.public_key}\" >> /home/${var.user_uid_1000}/.ssh/authorized_keys"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      host     = "${self.ipv4_address}"
      private_key = "${tls_private_key.ssh_key.private_key_pem}"
    }
  }
}

output "server_ip_ubuntu20" {
 value = "${hcloud_server.ubuntu20.ipv4_address}"
}

# Create ansible inventory
resource "local_file" "AnsibleInventory" {
 content = templatefile("inventory.tmpl", {
  name = hcloud_server.ubuntu20.name
  ip = hcloud_server.ubuntu20.ipv4_address
  port = 22
  user = "${var.user_uid_1000}"
  sudopass = "${var.pass_uid_1000}"
 })

 filename = "inventory"
}
