# Complete Apollo MCP Server Setup - Command Reference

This document contains every command needed to recreate the Apollo MCP Server deployment from scratch.

---

## Prerequisites

- Azure CLI installed and configured
- Docker Desktop running (for local testing)
- Node.js and npm installed
- Git installed
- Active Azure subscription

---

## Part 1: Local Docker Setup and Testing

### 1. Navigate to project directory
```powershell
cd C:\Users\shash\git_repos\graphql_demo\mcp
```

### 2. Start local Docker container
```powershell
docker compose up -d
```

### 3. Verify container is running
```powershell
docker logs apollo-mcp-server
```

### 4. Test health endpoint
```powershell
curl http://localhost:8000/health
```

### 5. Test with MCP Inspector
```powershell
npm install -g @modelcontextprotocol/inspector
npx @modelcontextprotocol/inspector http://localhost:8000
```

### 6. Stop local container (when done testing)
```powershell
docker compose down
```

---

## Part 2: Azure Deployment (Complete Flow)

### Step 1: Login to Azure
```powershell
az login
```

### Step 2: Set Variables
```powershell
$ResourceGroupName = "rg-apollo-mcp-demo"
$Location = "eastus"
$ContainerName = "apollo-mcp-server"
$DnsNameLabel = "apollo-mcp-$(Get-Random -Maximum 9999)"
$AcrName = "acrapollo$(Get-Random -Maximum 9999)"
```

### Step 3: Register Required Azure Providers
```powershell
# Register Container Instance provider
az provider register --namespace Microsoft.ContainerInstance

# Register Container Registry provider
az provider register --namespace Microsoft.ContainerRegistry

# Wait for registration (check every 10 seconds)
while ((az provider show --namespace Microsoft.ContainerInstance --query "registrationState" --output tsv) -ne "Registered") { 
    Write-Host "Waiting for Container Instance registration..."; 
    Start-Sleep -Seconds 10 
}

while ((az provider show --namespace Microsoft.ContainerRegistry --query "registrationState" --output tsv) -ne "Registered") { 
    Write-Host "Waiting for Container Registry registration..."; 
    Start-Sleep -Seconds 10 
}

Write-Host "All providers registered successfully!"
```

### Step 4: Create Resource Group
```powershell
az group create --name $ResourceGroupName --location $Location
```

### Step 5: Create Azure Container Registry
```powershell
az acr create `
    --resource-group $ResourceGroupName `
    --name $AcrName `
    --sku Basic `
    --admin-enabled true
```

### Step 6: Get ACR Credentials
```powershell
$acrLoginServer = az acr show --name $AcrName --query loginServer --output tsv
$acrUsername = az acr credential show --name $AcrName --query username --output tsv
$acrPassword = az acr credential show --name $AcrName --query "passwords[0].value" --output tsv

Write-Host "ACR Login Server: $acrLoginServer"
Write-Host "ACR Username: $acrUsername"
```

### Step 7: Build and Push Docker Image to ACR
```powershell
# Navigate to mcp directory (where Dockerfile is located)
cd C:\Users\shash\git_repos\graphql_demo\mcp

# Build image directly in ACR (no local Docker build needed)
az acr build --registry $AcrName --image apollo-mcp-server:v1 --file Dockerfile .
```

### Step 8: Deploy Container to ACI
```powershell
az container create `
    --resource-group $ResourceGroupName `
    --name $ContainerName `
    --image "$acrLoginServer/apollo-mcp-server:v1" `
    --registry-login-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --dns-name-label $DnsNameLabel `
    --ports 8000 `
    --cpu 1 `
    --memory 1 `
    --os-type Linux `
    --restart-policy Always
```

### Step 9: Monitor Deployment
```powershell
# Wait for provisioning
while ($true) {
    $state = az container show --resource-group $ResourceGroupName --name $ContainerName --query "provisioningState" --output tsv 2>$null
    if ($state -eq "Succeeded") {
        Write-Host "Container provisioned successfully!"
        break
    } elseif ($state -eq "Failed") {
        Write-Host "Container provisioning failed!"
        break
    }
    Write-Host "Current state: $state"
    Start-Sleep -Seconds 5
}

# Check logs
az container logs --resource-group $ResourceGroupName --name $ContainerName

# Get URL
$fqdn = az container show --resource-group $ResourceGroupName --name $ContainerName --query "ipAddress.fqdn" --output tsv
Write-Host "================================================"
Write-Host "Apollo MCP Server URL: http://$fqdn:8000"
Write-Host "Health Check: http://$fqdn:8000/health"
Write-Host "================================================"
```

### Step 10: Test Deployment
```powershell
# Test health endpoint
curl "http://$fqdn:8000/health"

# Test with MCP Inspector
npx @modelcontextprotocol/inspector "http://$fqdn:8000"
```

---

## Part 3: Update and Redeploy

### When config or data files change:

```powershell
# 1. Navigate to mcp directory
cd C:\Users\shash\git_repos\graphql_demo\mcp

# 2. Rebuild image with new version tag
az acr build --registry $AcrName --image apollo-mcp-server:v2 --file Dockerfile .

# 3. Delete old container
az container delete --resource-group $ResourceGroupName --name $ContainerName --yes

# 4. Deploy new version
az container create `
    --resource-group $ResourceGroupName `
    --name $ContainerName `
    --image "$acrLoginServer/apollo-mcp-server:v2" `
    --registry-login-server $acrLoginServer `
    --registry-username $acrUsername `
    --registry-password $acrPassword `
    --dns-name-label $DnsNameLabel `
    --ports 8000 `
    --cpu 1 `
    --memory 1 `
    --os-type Linux `
    --restart-policy Always

# 5. Monitor and test
az container logs --resource-group $ResourceGroupName --name $ContainerName
```

---

## Part 4: Cleanup

### Stop container (saves costs)
```powershell
az container stop --resource-group $ResourceGroupName --name $ContainerName
```

### Start container again
```powershell
az container start --resource-group $ResourceGroupName --name $ContainerName
```

### Delete everything
```powershell
az group delete --name $ResourceGroupName --yes --no-wait
```

### Verify deletion
```powershell
az group show --name $ResourceGroupName
```

---

## Part 5: Git and GitHub Setup

### Initialize and push to GitHub
```powershell
# Navigate to project root
cd C:\Users\shash\git_repos\graphql_demo

# Initialize git (if not already done)
git init

# Add all files
git add .

# Commit
git commit -m "Add Apollo MCP Server deployment to Azure with complete documentation"

# Add remote (create repo on GitHub first)
git remote add origin https://github.com/YOUR_USERNAME/graphql_demo.git

# Rename branch to main
git branch -M main

# Pull remote changes (if any)
git pull origin main --allow-unrelated-histories

# Push to GitHub
git push -u origin main
```

---

## Critical Files Required

### 1. mcp_config.yaml
```yaml
endpoint: "https://af-graphql-demo-20251122.azurewebsites.net/api/graphql"

transport:
  type: streamable_http
  port: 8000
  stateful_mode: false

auth:
  disabled: true

introspection:
  execute:
    enabled: true
  introspect:
    enabled: true
    minify: true
  search:
    enabled: true
    minify: true
  validate:
    enabled: true

operations:
  source: local
  paths:
    - ./data/operations

schema:
  source: local
  path: ./data/api.graphql

cors:
  enabled: true
  allow_any_origin: true
  allow_methods: ["GET", "POST", "OPTIONS"]
  allow_headers: ["content-type", "mcp-protocol-version", "mcp-session-id"]

health_check:
  enabled: true
  path: "/health"

logging:
  level: info

overrides:
  mutation_mode: all
  enable_explorer: false
```

### 2. Dockerfile
```dockerfile
FROM ghcr.io/apollographql/apollo-mcp-server:latest

# Copy configuration and data
COPY mcp_config.yaml /data/mcp_config.yaml
COPY data /data/data

# Expose the default port
EXPOSE 8000

# Run the Apollo MCP Server with config as argument
CMD ["mcp_config.yaml"]
```

### 3. docker-compose.yml
```yaml
services:
  apollo-mcp-server:
    image: ghcr.io/apollographql/apollo-mcp-server:latest
    container_name: apollo-mcp-server
    ports:
      - "8000:8000"
    volumes:
      - ./:/app:ro
    working_dir: /app
    command: ["mcp_config.yaml"]
    restart: unless-stopped
    environment:
      - NODE_ENV=production
```

### 4. Directory Structure
```
graphql_demo/
├── mcp/
│   ├── mcp_config.yaml
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .dockerignore
│   ├── README.md
│   ├── AZURE_DEPLOYMENT.md
│   ├── AZURE_DEPLOYMENT_COMMANDS.md
│   ├── azure-deploy.ps1
│   ├── azure-cleanup.ps1
│   ├── azure-logs.ps1
│   └── data/
│       ├── api.graphql
│       └── operations/
│           ├── GetAgentById.graphql
│           ├── GetAllAgents.graphql
│           └── GetAllCustomers.graphql
├── src/
├── graphql/
├── package.json
└── README.md
```

---

## Troubleshooting Commands

### Check container status
```powershell
az container show --resource-group $ResourceGroupName --name $ContainerName --query "provisioningState"
```

### View container logs
```powershell
az container logs --resource-group $ResourceGroupName --name $ContainerName
```

### View live logs (polling)
```powershell
while ($true) {
    Clear-Host
    Write-Host "=== Apollo MCP Server Logs ==="
    az container logs --resource-group $ResourceGroupName --name $ContainerName --tail 50
    Start-Sleep -Seconds 5
}
```

### Check ACR images
```powershell
az acr repository list --name $AcrName --output table
az acr repository show-tags --name $AcrName --repository apollo-mcp-server --output table
```

### Get container details
```powershell
az container show --resource-group $ResourceGroupName --name $ContainerName --output json
```

### Test endpoints
```powershell
$fqdn = az container show --resource-group $ResourceGroupName --name $ContainerName --query "ipAddress.fqdn" --output tsv
curl "http://$fqdn:8000/health"
```

---

## Cost Management

### Current Resource Costs (Pay-as-you-go)
- **ACI (1 vCPU, 1GB)**: ~$0.03/day = ~$1/month
- **ACR Basic**: ~$0.17/day = ~$5/month
- **Total**: ~$6/month if running 24/7

### Cost Saving Tips
1. Stop container when not in use: `az container stop`
2. Delete resources after testing: `az group delete`
3. Use smaller CPU/memory if possible
4. Set up auto-shutdown schedules

---

## Success Criteria

✅ Local Docker container runs and responds to health checks  
✅ ACR successfully stores custom Docker image  
✅ ACI container deploys without CrashLoopBackOff  
✅ Container logs show "Starting MCP server in Streamable HTTP mode"  
✅ Health endpoint returns `{"status":"UP"}`  
✅ MCP Inspector can connect and shows available tools  
✅ GraphQL operations are loaded (GetAgentById, GetAllAgents, GetAllCustomers)  
✅ Code pushed to GitHub repository  

---

## Final Deployed URLs

- **Production URL**: http://apollo-mcp-8718.eastus.azurecontainer.io:8000
- **Health Check**: http://apollo-mcp-8718.eastus.azurecontainer.io:8000/health
- **GitHub Repo**: https://github.com/shashank-tiwari/graphql_demo
- **GraphQL API**: https://af-graphql-demo-20251122.azurewebsites.net/api/graphql

---

## Notes

- All PowerShell commands assume you're running from the correct directory
- DNS names must be globally unique - use random numbers
- ACR names must be globally unique and lowercase (5-50 alphanumeric chars)
- Container takes 2-5 minutes to fully provision
- Config changes require rebuild and redeploy (config is baked into image)
- Keep ACR credentials secure - store in Azure Key Vault for production
- Use managed identities instead of admin credentials in production

---

## Quick Commands Summary

```powershell
# Full deployment in one go (after variables are set)
az login
az group create --name $ResourceGroupName --location $Location
az acr create --resource-group $ResourceGroupName --name $AcrName --sku Basic --admin-enabled true
$acrLoginServer = az acr show --name $AcrName --query loginServer --output tsv
$acrUsername = az acr credential show --name $AcrName --query username --output tsv
$acrPassword = az acr credential show --name $AcrName --query "passwords[0].value" --output tsv
az acr build --registry $AcrName --image apollo-mcp-server:v1 --file Dockerfile .
az container create --resource-group $ResourceGroupName --name $ContainerName --image "$acrLoginServer/apollo-mcp-server:v1" --registry-login-server $acrLoginServer --registry-username $acrUsername --registry-password $acrPassword --dns-name-label $DnsNameLabel --ports 8000 --cpu 1 --memory 1 --os-type Linux --restart-policy Always
$fqdn = az container show --resource-group $ResourceGroupName --name $ContainerName --query "ipAddress.fqdn" --output tsv
Write-Host "Deployed at: http://$fqdn:8000"
```
