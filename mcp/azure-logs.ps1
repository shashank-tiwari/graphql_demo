# View Azure Container Instance Logs
# Quick script to view the running container logs

param(
    [string]$ResourceGroupName = "rg-apollo-mcp-demo",
    [string]$ContainerName = "apollo-mcp-server",
    [switch]$Follow
)

Write-Host "Fetching logs for container: $ContainerName" -ForegroundColor Cyan
Write-Host ""

if ($Follow) {
    # Note: Azure CLI doesn't support live follow, so we'll poll
    Write-Host "Polling logs every 5 seconds (Ctrl+C to stop)..." -ForegroundColor Yellow
    Write-Host ""
    
    while ($true) {
        Clear-Host
        Write-Host "=== Apollo MCP Server Logs ===" -ForegroundColor Cyan
        az container logs --resource-group $ResourceGroupName --name $ContainerName --tail 50
        Start-Sleep -Seconds 5
    }
} else {
    az container logs --resource-group $ResourceGroupName --name $ContainerName
}
