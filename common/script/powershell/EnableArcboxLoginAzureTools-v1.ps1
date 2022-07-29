#requires -version 2

<#
.SYNOPSIS
  Log the azure command line tools
.EXAMPLE
  Enable-Arbox-Login-Azure-Tool
#>
function Enable-Arbox-Login-Azure-Tool {
    # Required for azcopy
    Write-Header "Az PowerShell Login"
    $azurePassword = ConvertTo-SecureString $Env:spnClientSecret -AsPlainText -Force
    $psCred = New-Object System.Management.Automation.PSCredential($Env:spnClientID , $azurePassword)
    Connect-AzAccount -Credential $psCred -TenantId $Env:spnTenantId -ServicePrincipal

    # Required for CLI commands
    Write-Header "Az CLI Login"
    az login --service-principal --username $Env:spnClientID --password $Env:spnClientSecret --tenant $Env:spnTenantId
}