#!/usr/bin/env bash
# set -x

# Creates the relevant storage account to persist terraform state
# source your .env file
. .env
# ...or set/override values here:
#TF_LOCATION=
#TF_RESOURCE_GROUP_NAME=
#TF_STORAGE_ACCOUNT_NAME=
#TF_CONTAINER_NAME=
#
# !! Make sure you set the same values for tfstate in .github/workflows/terraform-deploy-infra.yml !!

# Create or use existing Resource Group
RG_EXISTS=$(az group list --query "[?name=='$TF_RESOURCE_GROUP_NAME'].name" -o tsv)
if [ "$RG_EXISTS" = "$TF_RESOURCE_GROUP_NAME" ]; then
    echo "Azure Resource Group $TF_RESOURCE_GROUP_NAME already exists."
    RG_ID=$(az group list --query "[?name=='$TF_RESOURCE_GROUP_NAME'].id" -o tsv)
else
    # Create Azure Resource Group
    echo "Creating Resource Group $TF_RESOURCE_GROUP_NAME..."
    RG_ID=$(az group create -l "$TF_LOCATION" --name "$TF_RESOURCE_GROUP_NAME" --query id -o tsv) \
      || croak "Failed to create Resource Group"
fi

# Create or use existing Storage Account
SA_EXISTS=$(az storage account list --query "[?name=='$TF_STORAGE_ACCOUNT_NAME'].name" -g "$TF_RESOURCE_GROUP_NAME" -o tsv)
if [ "$SA_EXISTS" = "$TF_STORAGE_ACCOUNT_NAME" ]; then
    echo "Azure Storage Account $TF_STORAGE_ACCOUNT_NAME already exists."
    SA_ID=$(az storage account list --query "[?name=='$TF_STORAGE_ACCOUNT_NAME'].id" -g "$TF_RESOURCE_GROUP_NAME" -o tsv)
else
    # Create Azure Storage Account
    echo "Creating Storage Account $TF_STORAGE_ACCOUNT_NAME..."
    SA_ID=$(az storage account create -l "$TF_LOCATION" --name "$TF_STORAGE_ACCOUNT_NAME" -g "$TF_RESOURCE_GROUP_NAME" --query id -o tsv) \
      || croak "Failed to create Storage Account"
fi

# # Create Storage Container
# az storage container create  --name $TF_CONTAINER_NAME --account-name "$TF_STORAGE_ACCOUNT_NAME"

# Create or use existing Storage Container
CONTAINER_EXISTS=$(az storage container list --query "[?name=='$TF_CONTAINER_NAME'].name" --account-name "$TF_STORAGE_ACCOUNT_NAME" -o tsv)
if [ "$CONTAINER_EXISTS" = "$TF_CONTAINER_NAME" ]; then
    echo "Azure Storage Container $TF_CONTAINER_NAME already exists."
    CONTAINER_ID=$(az storage container list --query "[?name=='$TF_CONTAINER_NAME'].id" --account-name "$TF_STORAGE_ACCOUNT_NAME" -o tsv)
else
    # Create Azure Storage Container
    echo "Creating Storage Container $TF_CONTAINER_NAME..."
    CONTAINER_ID=$(az storage container create --name "$TF_CONTAINER_NAME" --account-name "$TF_STORAGE_ACCOUNT_NAME" --query id -o tsv) \
      || croak "Failed to create Storage Container"
fi
