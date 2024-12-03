terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = "dop_v1_test"
}

variable "ssh_public_keys" {
  description = "List of SSH public keys"
  type        = list(string)
}

resource "digitalocean_droplet" "iot-stack" {
  name       = "iot-stack"
  image      = "ubuntu-22-04-x64"
  region     = "fra1"
  size       = "s-2vcpu-4gb"
  monitoring = true
  ssh_keys   = var.ssh_public_keys
  user_data  = <<-EOF
    #!/bin/bash
    sudo apt-get update
    
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose docker-compose-plugin
    
    sudo useradd -m -s /bin/bash iot-user
    echo "iot-user:password" | sudo chpasswd
    sudo usermod -aG sudo iot-user
    sudo usermod -aG docker iot-user

    sudo -u iot-user git clone https://github.com/alundbergs/automated-iot-stack.git /home/iot-user/iot-stack-compose

    cd /home/iot-user/iot-stack-compose
    sudo chmod u+x /home/iot-user/iot-stack-compose

    docker-compose up -d 
  EOF
}

resource "digitalocean_firewall" "services_firewall" {
  name       = "services-firewall"
  droplet_ids = [digitalocean_droplet.iot-stack.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "1880"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "3000"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "1883"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "8086"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "9000"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "all"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

output "droplet_ip" {
  value = digitalocean_droplet.iot-stack.ipv4_address
}
