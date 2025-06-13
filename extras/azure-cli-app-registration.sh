#!/usr/bin/env bash
# Azure CLI App Registration for OneNote Sync
# Use this if you have Azure CLI access but not portal access

echo "OneNote App Registration via Azure CLI"
echo "====================================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Azure CLI not found. Install it first:"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Login to Azure
echo "Logging in to Azure..."
az login

# Create app registration
echo "Creating app registration..."
APP_ID=$(az ad app create \
    --display-name "OneNote Sync Tool" \
    --public-client-redirect-uris "http://localhost" \
    --query appId \
    --output tsv)

if [ $? -eq 0 ]; then
    echo "✅ App registration created successfully!"
    echo "📋 Application (Client) ID: $APP_ID"
    echo ""
    echo "Now add the required permissions:"
    echo "az ad app permission add --id $APP_ID --api 00000003-0000-0000-c000-000000000000 --api-permissions df85f4d6-205c-4ac5-a5ea-6bf408dba283=Scope"
    echo "az ad app permission add --id $APP_ID --api 00000003-0000-0000-c000-000000000000 --api-permissions 615e26af-c38a-4150-ae3e-c3b0d4cb1d6a=Scope"
    echo ""
    echo "Grant admin consent (if you have permissions):"
    echo "az ad app permission admin-consent --id $APP_ID"
    echo ""
    echo "Save this Client ID in your OneNote sync configuration:"
    echo "~/.config/onenote-sync/config.yaml"
else
    echo "❌ Failed to create app registration"
    echo "You may not have sufficient permissions"
fi
