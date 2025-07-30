
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
2. Prepare your Azure Subscription for OIDC: `azure-scripts/azure-oidc-setup.sh Github-GPP-OIDC  <Githup_Repo_URL>`
3. Prepare your Github repo for OIDC by publishing these reposiory secrets:
   - `AZURE_CLIENT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `AZURE_TENANT_ID`
4. Choose Azure variables for Terraform remote tfstate in `.env` (see `.env.template`)
5. Prepare Azure for Terraform remote tfstate storage: `azure-scripts/azure-tfstate-setup.sh`
6. Push changes to the `main` branch or open pull-requests to trigger the GitHub Actions workflow.

### Development environment: github --> azure

a. Make sure you are logged in to your Azure subscription,
b. source an `.env` file (from .env.template) into your current shell with values that point at the Azure subscription that you logged into
c. set/verify relevant Azure tfstate values in `infra/dev.azurerm.tfbackend`
d. use terraform or tofu commands in infra/ folder or prefixed with --chdir, e.g.: 

```bash
cd infra/
tofu init -backend-config=dev.azurerm.tfbackend # [-upgrade] [-reconfigure]
# Phase 1: Infra - we need to plan up to a working AKS cluster with Bastion VM(s), so we can start tunneling in:
tofu plan -var-file=dev.tfvars -target=module.bastion.azurerm_linux_virtual_machine.vm1[0] -out=infra.tfplan
tofu apply infra.tfplan
# Phase 2: CRDs - we can now strat using the Helm provider and deploy Charts, using the tunnel from the previous phase:
./azure-private.sh tofu plan -var-file=dev.tfvars -out=crds.tfplan
./azure-private.sh tofu apply crds.tfplan
...
```

## Directory Structure

- `.github/workflows/terraform-deploy-infra.yml`: GitHub Actions workflow to deploy infrastructure.
- `azure-scripts/`: scripts to prepare Azure subscription, i.e. OIDC, state, ...
- `infra/`: Terraform code and configurations.
