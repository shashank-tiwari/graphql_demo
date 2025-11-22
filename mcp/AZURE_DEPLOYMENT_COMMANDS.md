# Apollo MCP Server - Azure Deployment Commands

## Complete Command Reference

This document contains all commands needed to deploy the Apollo MCP Server to Azure Container Instances.

---

## Prerequisites

1. Azure CLI installed and logged in
2. Docker Desktop running (for local testing)
3. Azure subscription with appropriate permissions

---

## Step 1: Login to Azure

```powershell
az login
```

---

## Step 2: Set Variables

```powershell
$ResourceGroupName = "rg-apollo-mcp-demo"
$Location = "eastus"
$ContainerName = "apollo-mcp-server"
$ImageTag = "latest"
$DnsNameLabel = "apollo-mcp-$(Get-Random -Maximum 9999)"
$StorageAccountName = "stamcp$(Get-Random -Maximum 99999)"
```

---

## Step 3: Register Required Azure Providers

```powershell
# Register Container Instance provider
az provider register --namespace Microsoft.ContainerInstance

# Register Container Registry provider (if using ACR)
az provider register --namespace Microsoft.ContainerRegistry

# Check registration status (wait until "Registered")
az provider show --namespace Microsoft.ContainerInstance --query "registrationState" --output tsv
```

---

## Step 4: Create Resource Group

```powershell
az group create --name $ResourceGroupName --location $Location
```

---

## ~~Step 5-7: Storage Account Setup~~ (NOT NEEDED)

**Note:** When using the custom Docker image approach (recommended), Azure Storage Account is not required. Skip to Step 10 to build the custom image.

---

## ~~Step 8-9: Upload Configuration Files~~ (NOT NEEDED)

**Note:** When using the custom Docker image approach (recommended), you don't need to create Azure File Share or upload files. The configuration and data files are baked into the Docker image via the Dockerfile.

If you still want to use Azure File Share for dynamic config updates, see the "Alternative: Dynamic Config via File Share" section at the end of this document.

---

## Step 10: Build Custom Docker Image in ACR

The Apollo MCP Server public image doesn't work directly in ACI. Build a custom image with your config baked in:

```powershell
# Set ACR name
$AcrName = "acrapollo$(Get-Random -Maximum 9999)"

# Create Azure Container Registry
az acr create `
    --resource-group $ResourceGroupName `
    --name $AcrName `
    --sku Basic `
    --admin-enabled true

# Get ACR credentials
$acrLoginServer = az acr show --name $AcrName --query loginServer --output tsv
$acrUsername = az acr credential show --name $AcrName --query username --output tsv
$acrPassword = az acr credential show --name $AcrName --query "passwords[0].value" --output tsv

# Build and push image directly in ACR (no local Docker needed)
az acr build --registry $AcrName --image apollo-mcp-server:v1 --file Dockerfile .
```

**Note:** This uses the Dockerfile in the mcp directory which copies config and data files into the image.

---

## Step 11: Deploy Custom Image to ACI

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

**Note:** This command takes 2-5 minutes to complete. No Azure File Share needed - config is baked into the image.

---

## Step 12: Get Container URL

```powershell
$fqdn = az container show `
    --resource-group $ResourceGroupName `
    --name $ContainerName `
    --query "ipAddress.fqdn" `
    --output tsv

$ip = az container show `
    --resource-group $ResourceGroupName `
    --name $ContainerName `
    --query "ipAddress.ip" `
    --output tsv

Write-Host "================================================"
Write-Host "Apollo MCP Server Deployed Successfully!"
Write-Host "================================================"
Write-Host "URL: http://$fqdn:8000"
Write-Host "IP: $ip"
Write-Host "Health Check: http://$fqdn:8000/health"
Write-Host "================================================"
```

---

## Verification Commands

### Check container status
```powershell
az container show `
    --resource-group $ResourceGroupName `
    --name $ContainerName `
    --query "provisioningState" `
    --output tsv
```

### View container logs
```powershell
az container logs `
    --resource-group $ResourceGroupName `
    --name $ContainerName
```

### Test health endpoint
```powershell
curl http://$fqdn:8000/health
```

### Test with MCP Inspector
```powershell
npx @modelcontextprotocol/inspector http://$fqdn:8000
```

---

## Management Commands

### Restart container
```powershell
az container restart `
    --resource-group $ResourceGroupName `
    --name $ContainerName
```

### Stop container (saves costs)
```powershell
az container stop `
    --resource-group $ResourceGroupName `
    --name $ContainerName
```

### Start container
```powershell
az container start `
    --resource-group $ResourceGroupName `
    --name $ContainerName
```

### Delete container only
```powershell
az container delete `
    --resource-group $ResourceGroupName `
    --name $ContainerName `
    --yes
```

---

## Update Configuration

### Update config file and redeploy
```powershell
# Edit your local mcp_config.yaml or data files, then rebuild
az acr build --registry $AcrName --image apollo-mcp-server:v2 --file Dockerfile .

# Delete old container
az container delete --resource-group $ResourceGroupName --name $ContainerName --yes

# Deploy new version
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
```

---

## Cleanup Commands

### Delete entire resource group (removes everything)
```powershell
az group delete `
    --name $ResourceGroupName `
    --yes `
    --no-wait
```

### Check deletion status
```powershell
az group show --name $ResourceGroupName
```

---

## Troubleshooting

### View detailed container information
```powershell
az container show `
    --resource-group $ResourceGroupName `
    --name $ContainerName `
    --output json
```

### Check ACR images
```powershell
az acr repository list --name $AcrName --output table
az acr repository show-tags --name $AcrName --repository apollo-mcp-server --output table
```

### View live logs (PowerShell polling)
```powershell
while ($true) {
    Clear-Host
    Write-Host "=== Apollo MCP Server Logs ===" -ForegroundColor Cyan
    az container logs --resource-group $ResourceGroupName --name $ContainerName --tail 50
    Start-Sleep -Seconds 5
}
```

---

## Common Issues

### Issue: Provider not registered
**Solution:** Run provider registration commands and wait for "Registered" status

### Issue: Storage key not set
**Solution:** Re-run Step 6 to get the storage key

### Issue: Container fails to start
**Solution:** Check logs with `az container logs` command

### Issue: Cannot connect to URL
**Solution:** 
1. Check container is running: `az container show --query "instanceView.state"`
2. Verify ports are exposed
3. Check firewall/network settings

---

## Cost Estimate

**Daily costs for testing (pay-as-you-go):**
- ACI (1 vCPU, 1GB): ~$0.03/day (~$1/month if running 24/7)
- ACR Basic: ~$0.17/day (~$5/month)
- **Total: ~$6/month**

**Cost savings:**
- Stop container when not in use: ~$5/month (ACR only)
- Delete everything after testing: $0

---

## Production Considerations

For production deployment, consider:

1. **VNet Integration** - Deploy in private network
2. **Private Endpoints** - No public internet access
3. **Azure Monitor** - Add Application Insights
4. **API Management** - Add authentication/rate limiting
5. **Managed Identity** - Replace storage keys
6. **Container Apps** - Better autoscaling for production
7. **Multi-region** - High availability setup

---

## Quick Redeploy

To quickly redeploy with same settings:

```powershell
# Set variables (use same names as initial deployment)
$ResourceGroupName = "rg-apollo-mcp-demo"
$ContainerName = "apollo-mcp-server"

# Delete and recreate container
az container delete --resource-group $ResourceGroupName --name $ContainerName --yes
# Then run Step 10 again
```

---

## Important Notes

- All commands assume you're in the `mcp` directory
- DNS name must be globally unique
- ACR name must be globally unique and lowercase (5-50 alphanumeric characters)
- Container takes 2-5 minutes to fully start
- Config files are baked into the Docker image - to update, rebuild and redeploy
- The Dockerfile must be correct:
  ```dockerfile
  FROM ghcr.io/apollographql/apollo-mcp-server:latest
  COPY mcp_config.yaml /data/mcp_config.yaml
  COPY data /data/data
  EXPOSE 8000
  CMD ["mcp_config.yaml"]
  ```

---

## Alternative: Dynamic Config via File Share

If you need to update configuration without rebuilding the image, you can use Azure File Share:

### Create Storage and Upload Files
```powershell
$StorageAccountName = "stamcp$(Get-Random -Maximum 99999)"

az storage account create --name $StorageAccountName --resource-group $ResourceGroupName --location $Location --sku Standard_LRS

$storageKey = az storage account keys list --account-name $StorageAccountName --resource-group $ResourceGroupName --query "[0].value" --output tsv

az storage share create --name "apollo-config" --account-name $StorageAccountName --account-key $storageKey

az storage directory create --share-name "apollo-config" --name "data" --account-name $StorageAccountName --account-key $storageKey
az storage directory create --share-name "apollo-config" --name "data/operations" --account-name $StorageAccountName --account-key $storageKey

# Upload files
az storage file upload --share-name "apollo-config" --source "./mcp_config.yaml" --path "mcp_config.yaml" --account-name $StorageAccountName --account-key $storageKey
az storage file upload --share-name "apollo-config" --source "./data/api.graphql" --path "data/api.graphql" --account-name $StorageAccountName --account-key $storageKey
# ... upload operations files
```

### Deploy with File Share Mount
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
    --restart-policy Always `
    --azure-file-volume-account-name $StorageAccountName `
    --azure-file-volume-account-key $storageKey `
    --azure-file-volume-share-name "apollo-config" `
    --azure-file-volume-mount-path "/data"
```

**Note:** This approach adds ~$0.02/month in storage costs but allows config updates without rebuilding the image.
