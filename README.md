
# GPP-WOO provisioning

With AKS, Cilium CNI, ACR, cloudnative-pg and more.

This repository contains Terraform configurations and GitHub Actions workflow to provision an AKS cluster with Cilium CNI, an Azure Container Registry, and persistent storage for cloudnative-pg.

## Prerequisites

- Azure account
- Terraform/Tofu
- GitHub Actions secrets for Azure authentication

## Setup

### Production environment: github --> oidc --> azure

1. Clone the repository.
2. Prepare your Azure Subscription for OIDC: `scripts/azure-oidc-setup.sh Github-GPP-OIDC  <Githup_Repo_URL>`
3. Prepare your Github repo for OIDC by publishing these reposiory secrets:
   - `AZURE_CLIENT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `AZURE_TENANT_ID`
4. Choose Azure variables for Terraform remote tfstate in `.env` (see `.env.template`)
5. Prepare Azure for Terraform remote tfstate storage: `scripts/azure-tfstate-setup.sh`
6. Push changes to the `main` branch or open pull-requests to trigger the GitHub Actions workflow.

### Development environment: github --> azure

a. Make sure you are logged in to a (the) Azure subscription,
b. source an `.env` file (from .env.template) into your current shell with values that point at the Azure subscription that you logged into
c. set relevant Azure tfstate values in `infra/environments/dev/backend.tf`
d. use terraform or tofu commands with --chdir, e.g.: 

```bash
tofu -chdir=infra/environments/dev init -upgrade
tofu -chdir=infra/environments/dev plan
tofu -chdir=infra/environments/dev test
tofu -chdir=infra/environments/dev apply ...
...
```

## Directory Structure

- `.github/workflows/terraform-deploy-infra.yml`: GitHub Actions workflow to deploy infrastructure.
- `infra/`: Terraform configurations.
- `scripts/`: Various scripts to bootstrap the infrastructure.
