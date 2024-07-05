function Deploy-Workbook {
    param(
        [string]$MonitoringDir,
        [string]$workbookFileName
    )

    Write-Host "[$(Get-Date -Format t)] INFO: Deploying Azure Workbook $workbookFileName."
    Write-Host "`n"
    $workbookTemplateFilePath = "$MonitoringDir\$workbookFileName"
    # Read the content of the workbook template-file
    $content = Get-Content -Path $workbookTemplateFilePath -Raw
    # Replace placeholders with actual values
    $updatedContent = $content -replace 'rg-placeholder', $resourceGroup
    $updatedContent = $updatedContent -replace'/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/xxxx/providers/Microsoft.OperationalInsights/workspaces/xxxx', "/subscriptions/$($subscriptionId)/resourceGroups/$($Env:resourceGroup)/providers/Microsoft.OperationalInsights/workspaces/$($Env:workspaceName)"
    $updatedContent = $updatedContent -replace'/subscriptions/00000000-0000-0000-0000-000000000000', "/subscriptions/$($subscriptionId)"

    # Write the updated content back to the file
    Set-Content -Path $workbookTemplateFilePath -Value $updatedContent
    # Deploy the workbook
    try {
        New-AzResourceGroupDeployment -ResourceGroupName $Env:resourceGroup -TemplateFile $workbookTemplateFilePath -ErrorAction Stop
        Write-Host "[$(Get-Date -Format t)] INFO: Deployment of template-file $workbookTemplateFilePath succeeded."
    } catch {
        Write-Error "[$(Get-Date -Format t)] ERROR: Deployment of template-file $workbookTemplateFilePath failed. Error details: $PSItem.Exception.Message"
    }
}