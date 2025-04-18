# PetclinicAzureDeployment

This project provides infrastructure as code (IaC) and configuration management for deploying the Spring PetClinic application on Azure cloud platform. It combines Terraform for infrastructure provisioning and Ansible for configuration management.

## Project Structure

```
.
├── ansible/               # Ansible configuration and playbooks
│   ├── configs/          # Ansible configuration files
│   ├── roles/            # Ansible roles for different components
│   └── scripts/          # Helper scripts for Ansible
├── terraform/            # Terraform configuration
│   ├── configs/          # Terraform configuration files
│   ├── scripts/          # Helper scripts for Terraform
│   ├── main.tf          # Main Terraform configuration
│   ├── vars.tf          # Variable definitions
│   └── common.tfvars.json # Common variable values
```

## Prerequisites

- Azure CLI installed and configured
- Terraform >= 1.0.0
- Ansible >= 2.9.0
- Bash shell

## Setup and Deployment

### 1. Infrastructure Setup with Terraform

1. Navigate to the terraform directory:
   ```bash
   cd terraform
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review and modify variables in `common.tfvars.json` if needed

4. Apply the Terraform configuration:
   ```bash
   terraform apply -var-file="common.tfvars.json"
   ```

### 2. Configuration Management with Ansible

1. Navigate to the ansible directory:
   ```bash
   cd ansible
   ```

2. Run the Ansible playbook:
   ```bash
   ansible-playbook -i configs/inventory.ini playbooks/main.yml
   ```

## Components

The deployment includes:
- Azure Virtual Network
- Azure Virtual Machines
- Azure Storage
- Network Security Groups
- Other Azure resources as defined in Terraform configuration

## Configuration

- Terraform variables can be modified in `terraform/common.tfvars.json`
- Ansible variables can be modified in `ansible/configs/`
- Environment-specific configurations are stored in respective config directories

## Security

- Sensitive information should be stored in Azure Key Vault
- Network security groups are configured to restrict access
- SSH keys are used for VM access

## Maintenance

- Regular updates to Terraform and Ansible configurations are recommended
- Monitor Azure resources through Azure Portal
- Keep dependencies updated

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
