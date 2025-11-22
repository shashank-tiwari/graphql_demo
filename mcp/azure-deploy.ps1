# Azure Container Instance Deployment Script for Apollo MCP Server
# This script deploys the Apollo MCP Server to Azure Container Instances with public access

param(
    [string]$ResourceGroupName = "rg-apollo-mcp-demo",
    [string]$Location = "eastus",
    [string]$AcrName = "acrapollo$(Get-Random -Maximum 9999)",
    [string]$ContainerName = "apollo-mcp-server",
    [string]$ImageTag = "latest",
    [string]$DnsNameLabel = "apollo-mcp-$(Get-Random -Maximum 9999)"
)

Write-Host "====================================="
Write-Host "Apollo MCP Server - Azure Deployment"
Write-Host "====================================="
Write-Host ""

# Check if logged in to Azure
Write-Host "Checking Azure login status..."
$azAccount = az account show 2>$null | ConvertFrom-Json
if (-not $azAccount) {
    Write-Host "Not logged in to Azure. Please login..."
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure login failed"
        exit 1
    }
}

Write-Host "Logged in as: $($azAccount.user.name)"
Write-Host "Subscription: $($azAccount.name)"
Write-Host ""

# Create Resource Group
Write-Host "Creating resource group: $ResourceGroupName in $Location..."
az group create --name $ResourceGroupName --location $Location --output none
Write-Host "âœ“ Resource group created"
Write-Host ""

# Create Azure Container Registry
Write-Host "Creating Azure Container Registry: $AcrName..."
az acr create `
    --resource-group $ResourceGroupName `
    --name $AcrName `
    --sku Basic `
    --admin-enabled true `
    --output none

Write-Host "âœ“ ACR created"
Write-Host ""

# Get ACR credentials
Write-Host "Retrieving ACR credentials..."
$acrLoginServer = az acr show --name $AcrName --query loginServer --output tsv
$acrUsername = az acr credential show --name $AcrName --query username --output tsv
$acrPassword = az acr credential show --name $AcrName --query "passwords[0].value" --output tsv

Write-Host "âœ“ ACR Login Server: $acrLoginServer"
Write-Host ""

# Login to ACR
Write-Host "Logging in to ACR..."
docker login $acrLoginServer --username $acrUsername --password $acrPassword
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to login to ACR"
    exit 1
}
Write-Host "âœ“ Logged in to ACR"
Write-Host ""

# Build and tag the Docker image
Write-Host "Building Docker image..."
$localImageName = "apollo-mcp-server:$ImageTag"
$remoteImageName = "$acrLoginServer/apollo-mcp-server:$ImageTag"

# Build from the official Apollo image (we're not building custom, just tagging)
docker pull ghcr.io/apollographql/apollo-mcp-server:latest
docker tag ghcr.io/apollographql/apollo-mcp-server:latest $remoteImageName

Write-Host "âœ“ Image tagged as $remoteImageName"
Write-Host ""

# Push image to ACR
Write-Host "Pushing image to ACR..."
docker push $remoteImageName
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push image to ACR"
    exit 1
}
Write-Host "âœ“ Image pushed to ACR"
Write-Host ""

# Create Azure File Share for configuration files
Write-Host "Creating Azure Storage Account for configuration..."
$storageAccountName = "stamcp$(Get-Random -Maximum 99999)"
az storage account create `
    --name $storageAccountName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --sku Standard_LRS `
    --output none

$storageKey = az storage account keys list `
    --account-name $storageAccountName `
    --resource-group $ResourceGroupName `
    --query "[0].value" `
    --output tsv

az storage share create `
    --name "apollo-config" `
    --account-name $storageAccountName `
    --account-key $storageKey `
    --output none

Write-Host "âœ“ Storage account created: $storageAccountName"
Write-Host ""

# Upload configuration files
Write-Host "Uploading configuration files..."
az storage file upload `
    --share-name "apollo-config" `
    --source "./mcp_config.yaml" `
    --path "mcp_config.yaml" `
    --account-name $storageAccountName `
    --account-key $storageKey `
    --output none

az storage file upload `
    --share-name "apollo-config" `
    --source "./data/api.graphql" `
    --path "data/api.graphql" `
    --account-name $storageAccountName `
    --account-key $storageKey `
    --output none

# Upload operations
$operations = Get-ChildItem "./data/operations/*.graphql"
foreach ($op in $operations) {
    az storage file upload `
        --share-name "apollo-config" `
        --source $op.FullName `
        --path "data/operations/$($op.Name)" `
        --account-name $storageAccountName `
        --account-key $storageKey `
        --output none
}

Write-Host "âœ“ Configuration files uploaded"
Write-Host ""

# Deploy to Azure Container Instances
Write-Host "Deploying to Azure Container Instances..."
Write-Host "This may take a few minutes..."

az container create `
    --resource-group $ResourceGroupName `
    --name $ContainerName `
    --image $remoteImageName `
    --registry-login-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --dns-name-label $DnsNameLabel `
    --ports 8000 `
    --cpu 1 `
    --memory 1 `
    --restart-policy Always `
    --azure-file-volume-account-name $storageAccountName `
    --azure-file-volume-account-key $storageKey `
    --azure-file-volume-share-name "apollo-config" `
    --azure-file-volume-mount-path "/app" `
    --command-line "apollo-mcp-server /app/mcp_config.yaml" `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create container instance"
    exit 1
}

Write-Host "âœ“ Container instance created"
Write-Host ""

# Get container details
Write-Host "Retrieving container information..."
$containerInfo = az container show `
    --resource-group $ResourceGroupName `
    --name $ContainerName `
    --output json | ConvertFrom-Json

$fqdn = $containerInfo.ipAddress.fqdn
$ip = $containerInfo.ipAddress.ip

Write-Host ""
Write-Host "====================================="
Write-Host "Deployment Successful!"
Write-Host "====================================="
Write-Host ""
Write-Host "Apollo MCP Server URL: http://$fqdn:8000"
Write-Host "IP Address: $ip"
Write-Host "Health Check: http://$fqdn:8000/health"
Write-Host ""
Write-Host "Resource Group: $ResourceGroupName"
Write-Host "Container Registry: $AcrName"
Write-Host "Storage Account: $storageAccountName"
Write-Host ""
Write-Host "Test with MCP Inspector:"
Write-Host "npx @modelcontextprotocol/inspector http://$($fqdn):8000"
Write-Host ""
Write-Host "View logs:"
Write-Host "az container logs --resource-group $ResourceGroupName --name $ContainerName"
Write-Host ""
Write-Host "To delete all resources:"
Write-Host "az group delete --name $ResourceGroupName --yes --no-wait"
Write-Host ""

