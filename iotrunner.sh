#!/bin/bash

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting IOT infrastructure setup...${NC}"

echo -e "${YELLOW}Enter your DigitalOcean API token:${NC}"
read DIGITALOCEAN_TOKEN
echo ""

echo -e """${YELLOW}Enter SSH fingerprints. You can find them in the Digital Ocean security settings.
Add keys which you want your Digital Ocean machine to be accessed with.
Press Enter after each fingerprint, and type 'done' when finished:${NC}"""

SSH_FINGERPRINTS=()
while true; do
    read -p "Fingerprint: " fingerprint
    if [ "$fingerprint" == "done" ]; then
        break
    fi
    SSH_FINGERPRINTS+=("\"$fingerprint\"")
done

SSH_FINGERPRINTS_STR=$(IFS=,; echo "${SSH_FINGERPRINTS[*]}")

echo -e "${YELLOW}Installing Terraform...${NC}"
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install -y terraform

echo -e "${YELLOW}Cloning repository...${NC}"
git clone https://github.com/rzashakh/iot-stack.git

cd iot-stack

sed -i "s/token = \"dop_v1_test\"/token = \"$DIGITALOCEAN_TOKEN\"/" main.tf
echo -e "${GREEN}Updated main.tf with the provided DigitalOcean token.${NC}"

cat << EOF > terraform.tfvars
ssh_public_keys = [
  ${SSH_FINGERPRINTS_STR}
]
EOF
echo -e "${GREEN}Created terraform.tfvars file with provided SSH fingerprints.${NC}"

echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

echo -e "${YELLOW}Creating Terraform plan...${NC}"
terraform plan -out=tfplan

read -p "Do you want to apply the Terraform plan? (yes/no): " confirm
if [ "$confirm" = "yes" ]; then
  echo -e "${YELLOW}Applying Terraform plan...${NC}"
  terraform apply tfplan

  echo -e "${GREEN}Terraform apply completed successfully!${NC}"
  echo -e "${GREEN}Droplet IP:${NC} $(terraform output -raw droplet_ip)"
  echo -e "${YELLOW}Please wait for 7-15 minutes for the complete configuration of your IOT infrastructure on the droplet.${NC}"

else
  echo -e "${RED}Terraform apply cancelled.${NC}"
fi
