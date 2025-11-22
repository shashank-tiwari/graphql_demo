# Azure Cleanup Script for Apollo MCP Server
# This script removes all Azure resources created by the deployment

param(
    [string]$ResourceGroupName = "rg-apollo-mcp-demo",
    [switch]$Force
)

Write-Host "=====================================" -ForegroundColor Red
Write-Host "Azure Resource Cleanup" -ForegroundColor Red
Write-Host "=====================================" -ForegroundColor Red
Write-Host ""

if (-not $Force) {
    Write-Host "This will delete the following resource group and ALL its contents:" -ForegroundColor Yellow
    Write-Host "  - Resource Group: $ResourceGroupName" -ForegroundColor Yellow
    Write-Host ""
    
    $confirmation = Read-Host "Are you sure you want to continue? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Cleanup cancelled" -ForegroundColor Green
        exit 0
    }
}

Write-Host ""
Write-Host "Deleting resource group: $ResourceGroupName..." -ForegroundColor Yellow
Write-Host "This may take a few minutes..." -ForegroundColor Yellow

az group delete --name $ResourceGroupName --yes --no-wait

Write-Host ""
Write-Host "✓ Cleanup initiated. Resources will be deleted in the background." -ForegroundColor Green
Write-Host ""
Write-Host "To check deletion status:" -ForegroundColor Cyan
Write-Host "az group show --name $ResourceGroupName" -ForegroundColor White
Write-Host ""
