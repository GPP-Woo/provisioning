#!/bin/bash
# Setup Azure AD application, Service Principal and add Federated credentials for github actions
# workflows to use for authenticating to Azure using azcli, Tofu/Terraform, etc.
# (Thanks to Thomas Thornton for inspiration, see:
#  https://thomasthornton.cloud/2025/05/15/deploy-terraform-to-azure-with-oidc-and-github-actions/)
#
# Example usage:  azure-oidc-setup.sh Github-GPP-OIDC https://github.com/GPP-Woo/provisioning

# Error handler
croak() {
    echo "ERROR: $1"
    exit 1
}

# Configuration
[ $# -eq 2 ] || croak "Usage: $0 <App_Display_Name> <Githup_Repo_URL>"
APP_DISPLAY_NAME="$1"
GITHUB_REPO="$2"

# Verify Azure CLI is installed and we're logged in
if ! command -v az >& /dev/null; then
    croak "Azure CLI is not installed: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
fi
az account show >& /dev/null || croak "Must 'az login' first."

# Create or use existing Azure AD App
APP_EXISTS=$(az ad app list --display-name "$APP_DISPLAY_NAME" --query "[].displayName" -o tsv)
if [ "$APP_EXISTS" = "$APP_DISPLAY_NAME" ]; then
    echo "Azure AD application $APP_DISPLAY_NAME already exists."
    APP_ID=$(az ad app list --display-name "$APP_DISPLAY_NAME" --query "[0].appId" -o tsv)
else
    # Create Azure AD application registration
    echo "Creating Azure AD application $APP_DISPLAY_NAME..."
    APP_ID=$(az ad app create --display-name "$APP_DISPLAY_NAME" --query appId -o tsv) \
      || croak "Failed to create Azure AD application"
fi

# Create or use existing service principal
SP_EXISTS=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[].id" -o tsv)
if [ -n "$SP_EXISTS" ]; then
    echo "Service principal for $APP_DISPLAY_NAME already exists."
    SP_ID=$SP_EXISTS
else
    # Create service principal
    echo "Creating service principal for $APP_DISPLAY_NAME..."
    SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv) || croak "Failed to create service principal"
fi

# Function to create or update Federated credential
create_federated_credential() {
    local name=$1
    local subject=$2
    local description=$3

    # Create or use existing Federated credential
    CRED_EXISTS=$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$name'].name" -o tsv)
    if [ "$CRED_EXISTS" = "$name" ]; then
        echo "Federated credential $name already exists."
    else
        echo "Creating federated credential $name..."
        az ad app federated-credential create \
          --id "$APP_ID" \
          --parameters "{
            \"name\": \"$name\",
            \"issuer\": \"https://token.actions.githubusercontent.com\",
            \"subject\": \"$subject\",
            \"description\": \"$description\",
            \"audiences\": [\"api://AzureADTokenExchange\"]
          }" \
          || croak "Failed to create federated credential $name"
    fi
}

# Create federated credentials for different GitHub workflows
create_federated_credential "github-oidc-branch" "repo:$GITHUB_REPO:ref:refs/heads/main" "GitHub Actions OIDC - Branch Workflows (main)"
create_federated_credential "github-oidc-branch-renovate" "repo:$GITHUB_REPO:ref:refs/heads/renovate/configure" "GitHub Actions OIDC - Branch Renovate Workflows (renovate)"
create_federated_credential "github-oidc-pull-request" "repo:$GITHUB_REPO:pull_request" "GitHub Actions OIDC - Pull Request Workflows"

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
# Set subscription scope
SUBSCRIPTION_SCOPE="/subscriptions/$SUBSCRIPTION_ID"

let ROLE_ASSIGNED=0
# We'll reuse this block - therefor it is a function:
function AssignRole() {
    ROLE="$1"
    if [ -z "$ROLE" ]; then
        echo "WARNING: Specify ROLE to assign!"
        return
    fi
    # Check if subscription-level role assignment already exists to avoid duplicates
    EXISTING_ROLE=$(az role assignment list --assignee "$APP_ID" --scope "$SUBSCRIPTION_SCOPE" --role "$ROLE" --query "[].id" -o tsv)
    # unset ROLE_ASSIGNED
    if [ -n "$EXISTING_ROLE" ]; then
        echo "'$ROLE' role assignment already exists for this application at the subscription level."
        # ROLE_ASSIGNED=yes
        let ROLE_ASSIGNED=$ROLE_ASSIGNED+1
    else
        read -p "No '$ROLE' role assignment found for this APP_ID. Create (y/N)?" answer
        if expr "$answer" : "[Yy]" >& /dev/null; then
            # Assign permissions to the application at subscription level
            echo "Assigning '$ROLE' role to the application at subscription level..."
            az role assignment create --assignee "$APP_ID" --role "$ROLE" --scope "$SUBSCRIPTION_SCOPE"
            if [ $? -ne 0 ]; then
                echo "WARNING: Failed to assign '$ROLE' role to the application at subscription level."
            else
                echo "Successfully assigned role to application."
                let ROLE_ASSIGNED=$ROLE_ASSIGNED+1
            fi
        else
            echo "WARNING: Could not find '$ROLE' role assignment for this APP_ID."
            echo "         You may need to grant permissions before use from GitHub!"
        fi
    fi
}
# Now add two critical roles:
AssignRole "Contributor"
AssignRole "Role Based Access Control Administrator"

# Summary with more detailed subscription information
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "✅ Setup complete!"
echo "==========================================================================="
echo "  APPLICATION NAME:        $APP_DISPLAY_NAME"
echo "  SUBSCRIPTION ID:         $SUBSCRIPTION_NAME"
echo "  APPLICATION (CLIENT) ID: $APP_ID"
echo "  SERVICE PRINCIPAL ID:    $SP_ID"
echo "==========================================================================="
echo "For GitHub Actions, add these secrets to your repository:"
echo "  AZURE_CLIENT_ID:         $APP_ID"
echo "  AZURE_TENANT_ID:         $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID:   $SUBSCRIPTION_ID"
echo "==========================================================================="
case "$ROLE_ASSIGNED" in
 2) echo "The application was assigned needed roles at the subscription level. This"
    echo "allows management of ALL resources in the subscription."
    echo "==========================================================================="
    echo "SECURITY NOTE: Assigning roles at the subscription level grants broad"
    echo "permissions. Consider restricting to specific resource groups if possible."
    echo "==========================================================================="
    ;;
 0) echo "WARNING: NO role assigments could be made or found."
    ;;
 *) echo "WARNING: SOME role assignments could not be made."
esac