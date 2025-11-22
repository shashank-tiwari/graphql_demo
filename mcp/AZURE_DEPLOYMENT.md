# Azure Deployment - Quick Start Guide

## Prerequisites

1. **Azure CLI** - Install from: https://aka.ms/installazurecli
   ```powershell
   # Verify installation
   az --version
   ```

2. **Docker Desktop** - Already installed and running

3. **Azure Subscription** - Free tier works fine for testing

## Deployment Steps

### 1. Login to Azure
```powershell
az login
```

### 2. Deploy to Azure Container Instances
```powershell
cd c:\Users\shash\git_repos\graphql_demo\mcp
.\azure-deploy.ps1
```

**What this script does:**
- Creates Azure Resource Group
- Creates Azure Container Registry (ACR)
- Pushes Apollo MCP Server image to ACR
- Creates Azure Storage Account for config files
- Uploads `mcp_config.yaml`, schema, and operations
- Deploys ACI with public IP
- Returns the public URL

### 3. View Logs
```powershell
.\azure-logs.ps1
```

Or with live polling:
```powershell
.\azure-logs.ps1 -Follow
```

### 4. Test the Deployment
Once deployed, you'll get a URL like:
```
http://apollo-mcp-1234.eastus.azurecontainer.io:8000
```

Test health endpoint:
```powershell
curl http://apollo-mcp-1234.eastus.azurecontainer.io:8000/health
```

Test with MCP Inspector:
```powershell
npx @modelcontextprotocol/inspector http://apollo-mcp-1234.eastus.azurecontainer.io:8000
```

### 5. Cleanup Resources
When done testing:
```powershell
.\azure-cleanup.ps1
```

## Custom Deployment Options

Deploy with custom parameters:
```powershell
.\azure-deploy.ps1 `
    -ResourceGroupName "my-custom-rg" `
    -Location "westus2" `
    -DnsNameLabel "my-apollo-mcp"
```

## Cost Estimate (Pay-as-you-go)

For testing/learning:
- **ACI**: ~$0.0013/hour (1 vCPU, 1GB RAM) = ~$1/month if running 24/7
- **ACR Basic**: ~$5/month
- **Storage**: ~$0.02/month
- **Total**: ~$6-7/month (or stop ACI when not using = nearly free)

## Stop/Start Container

Stop (to save costs):
```powershell
az container stop --resource-group rg-apollo-mcp-demo --name apollo-mcp-server
```

Start:
```powershell
az container start --resource-group rg-apollo-mcp-demo --name apollo-mcp-server
```

## Troubleshooting

### Container won't start
Check logs:
```powershell
az container logs --resource-group rg-apollo-mcp-demo --name apollo-mcp-server
```

### Can't connect to URL
1. Check container state:
```powershell
az container show --resource-group rg-apollo-mcp-demo --name apollo-mcp-server
```

2. Verify port 8000 is exposed

3. Check if config files uploaded correctly:
```powershell
az storage file list `
    --share-name apollo-config `
    --account-name <storage-account-name> `
    --output table
```

### Update configuration
After changing config files, re-upload and restart:
```powershell
# Upload new config
az storage file upload --share-name apollo-config --source ./mcp_config.yaml --path mcp_config.yaml --account-name <storage-account>

# Restart container
az container restart --resource-group rg-apollo-mcp-demo --name apollo-mcp-server
```

## Next Steps

Once you've tested and verified:
1. Move to secured deployment (VNet + Private Endpoint)
2. Add Azure Monitor and Application Insights
3. Set up CI/CD pipeline
4. Implement proper authentication
5. Add API Management in front
