#!/bin/bash

# Azure Setup Script for Savoira Dev
# Run this script to set up Azure infrastructure

set -e

# Configuration
RESOURCE_GROUP="savoira-dev-rg"
LOCATION="eastus"
CONTAINER_REGISTRY="savoiradev"
POSTGRES_SERVER="savoira-postgres"
REDIS_CACHE="savoira-redis"
CONTAINER_APP_ENV="savoira-app-env"
CONTAINER_APP="savoira-dev-app"

echo "🚀 Setting up Azure infrastructure for Savoira Dev..."

# Create resource group
echo "📦 Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create container registry
echo "🐳 Creating Azure Container Registry..."
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $CONTAINER_REGISTRY \
  --sku Basic \
  --admin-enabled true

# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name $CONTAINER_REGISTRY --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name $CONTAINER_REGISTRY --query passwords[0].value --output tsv)

echo "📝 Container Registry Credentials:"
echo "Username: $ACR_USERNAME"
echo "Password: $ACR_PASSWORD"

# Create PostgreSQL server
echo "🗄️ Creating PostgreSQL server..."
POSTGRES_PASSWORD=$(openssl rand -base64 32)
az postgres flexible-server create \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER \
  --location $LOCATION \
  --admin-user postgres \
  --admin-password $POSTGRES_PASSWORD \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --public-access 0.0.0.0 \
  --storage-size 32 \
  --version 14

# Create database
az postgres flexible-server db create \
  --resource-group $RESOURCE_GROUP \
  --server-name $POSTGRES_SERVER \
  --database-name savoira

# Create Redis cache
echo "🔴 Creating Redis cache..."
az redis create \
  --resource-group $RESOURCE_GROUP \
  --name $REDIS_CACHE \
  --location $LOCATION \
  --sku Basic \
  --vm-size c0

# Create Container Apps environment
echo "🌐 Creating Container Apps environment..."
az containerapp env create \
  --name $CONTAINER_APP_ENV \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Get connection strings
POSTGRES_CONNECTION=$(az postgres flexible-server show-connection-string \
  --server-name $POSTGRES_SERVER \
  --database-name savoira \
  --admin-user postgres \
  --admin-password $POSTGRES_PASSWORD \
  --query connectionStrings.psql_cmd \
  --output tsv)

REDIS_CONNECTION=$(az redis list-keys \
  --name $REDIS_CACHE \
  --resource-group $RESOURCE_GROUP \
  --query primaryKey \
  --output tsv)

# Create Container App
echo "📱 Creating Container App..."
az containerapp create \
  --name $CONTAINER_APP \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --image nginx:latest \
  --target-port 3000 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 1.0 \
  --memory 2Gi

echo "✅ Azure infrastructure setup complete!"
echo ""
echo "📋 GitHub Secrets to configure:"
echo "AZURE_REGISTRY_USERNAME: $ACR_USERNAME"
echo "AZURE_REGISTRY_PASSWORD: $ACR_PASSWORD"
echo "PG_DATABASE_URL: postgresql://postgres:$POSTGRES_PASSWORD@$POSTGRES_SERVER.postgres.database.azure.com:5432/savoira"
echo "REDIS_URL: redis://:$REDIS_CONNECTION@$REDIS_CACHE.redis.cache.windows.net:6380"
echo "SAVOIRA_POSTGRES_ADMIN_PASSWORD: $POSTGRES_PASSWORD"
echo ""
echo "🔐 Generate these secrets:"
echo "ACCESS_TOKEN_SECRET: $(openssl rand -base64 32)"
echo "REFRESH_TOKEN_SECRET: $(openssl rand -base64 32)"
echo "LOGIN_TOKEN_SECRET: $(openssl rand -base64 32)"
echo "FILE_TOKEN_SECRET: $(openssl rand -base64 32)"
echo ""
echo "🌐 Your app will be available at:"
az containerapp show --name $CONTAINER_APP --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn --output tsv