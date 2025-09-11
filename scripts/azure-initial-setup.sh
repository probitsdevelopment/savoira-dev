#!/bin/bash

# Azure Initial Setup Script for Savoira Dev
# Run this script after installing Azure CLI and logging in

set -e

echo "🔧 Setting up Azure account for Savoira Dev deployment..."

# Check if logged in
echo "📋 Checking Azure login status..."
az account show --output table

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "📝 Using subscription: $SUBSCRIPTION_ID"

# Register required resource providers
echo "🔄 Registering required resource providers..."
az provider register --namespace Microsoft.ContainerRegistry --wait
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.DBforPostgreSQL --wait
az provider register --namespace Microsoft.Cache --wait

echo "✅ Resource providers registered successfully!"

# Create service principal for GitHub Actions
echo "🔐 Creating service principal for GitHub Actions..."
SP_NAME="savoira-dev-github-actions"

# Create the service principal and capture the output
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name $SP_NAME \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --sdk-auth)

echo "✅ Service principal created successfully!"
echo ""
echo "🔑 AZURE_CREDENTIALS secret for GitHub:"
echo "Copy this entire JSON and add it as AZURE_CREDENTIALS secret in GitHub:"
echo "================================================"
echo "$SP_OUTPUT"
echo "================================================"
echo ""

# Save to file for reference
echo "$SP_OUTPUT" > azure-credentials.json
echo "📁 Credentials also saved to azure-credentials.json (keep this secure!)"

echo ""
echo "🎯 Next steps:"
echo "1. Copy the JSON above and add it as 'AZURE_CREDENTIALS' secret in GitHub"
echo "2. Go to GitHub → Settings → Secrets and variables → Actions"
echo "3. Click 'New repository secret'"
echo "4. Name: AZURE_CREDENTIALS"
echo "5. Value: paste the JSON above"
echo "6. Run the main setup script: ./scripts/azure-setup.sh"
echo ""
echo "✅ Azure account setup complete!"