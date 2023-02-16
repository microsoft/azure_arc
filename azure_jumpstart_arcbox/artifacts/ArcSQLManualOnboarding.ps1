﻿param(
    [string]$subId = "<subscriptionId>",
    [string]$resourceGroup = "<resourceGroup>",
    [string]$sqlServerName = "<sqlServerName>"
)

$host.ui.RawUI.WindowTitle = “Onboarding...”

Add-Type -AssemblyName PresentationCore, PresentationFramework

$WarningPreference = 'SilentlyContinue'

$logLocation = 'C:\ArcBox\Logs'
$scriptLocation = 'C:\ArcBox'

# Define function to display pop-up message boxes

function Show-Message {
    param(
        [Parameter(Mandatory)]
        [string]$messageTitle,

        [Parameter(Mandatory)]
        [string]$messageBody,

        [Parameter(Mandatory)]
        [ValidateSet("None", "Hand", "Question", "Warning", "Asterisk")]
        [string]$messageImage,

        [Parameter(Mandatory)]
        [ValidateSet("OK", "OkCancel", "YesNoCancel", "YesNo")]
        [string]$messageButton
    )

    $top = New-Object System.Windows.Window -Property @{TopMost = $True}

    return [System.Windows.MessageBox]::Show($top, $messageBody, $messageTitle, $messageButton, $messageImage)
}

# Begin transcript

Start-Transcript -Path "${logLocation}\ArcSQLServer.log"

# Inform user of onboarding process and ask to proceed

$startMsg = @"
This script will onboard the VM 'ArcBox-SQL' as an Azure Arc-enabled SQL Server.

When you click 'OK', you will be redirected to the Micorsoft Device Authentication website. The code will be copied to the clipboard, so simply paste it in and complete the Microsoft authentication process.

To continue, you must be an Owner or User Access Administrator at the Subscription or Resource Group level.
"@

$continue = Show-Message 'Azure Arc-enabled SQL Server' $startMsg 'Asterisk' 'OkCancel'

if ($continue -eq 'Cancel') { throw [System.Exception] "Script cancelled by user" }

# PowerShell Settings

[string]$userName = "${sqlServerName}\Administrator"
[string]$userPassword = 'ArcDemo123!!'
[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

Set-Item WSMan:\localhost\Client\TrustedHosts -Value $sqlServerName -Force

# PowerShell Session Setup

$Server01 = New-PSSession -ComputerName $sqlServerName -Credential $credObject

Write-Host "Logging into ${sqlServerName} and installing Azure PowerShell (this will take some time)..."

Invoke-Command -Session $Server01 -ScriptBlock {Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force}
Invoke-Command -Session $Server01 -ScriptBlock {Install-Module -Name Az -AllowClobber -Scope CurrentUser -Repository PSGallery -WarningAction SilentlyContinue -Force}

Write-Host "Copying Azure Arc-enabled SQL onboarding script to ${sqlServerName}.."

Copy-Item -Path $scriptLocation\installArcAgentSQLUser.ps1 -Destination $scriptLocation -ToSession $Server01 -Force

# Authenticate to Azure PowerShell SDK

Write-Host "Authenticating to Azure PowerShell on ${sqlServerName}..."

$loginJob = Invoke-Command -Session $Server01 {Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop} -AsJob
$loginJobId = $loginJob.Id
$loginMessage = ''

do {
  Start-Sleep -Seconds 1
  Receive-Job -Id $loginJobId -Keep -WarningVariable loginMessage
} while (-not $loginMessage)

[regex]$rx = '((?<=enter the code )(?<Code>.*)(?= to authenticate))'
Set-Clipboard -Value $rx.match($loginMessage).Groups['Code'].Value

Write-Host "Opening Edge browser window, please paste authentication code from clipboard..."

$edge = Start-Process microsoft-edge:'http://www.microsoft.com/devicelogin' -WindowStyle Maximized -PassThru

Write-Host -NoNewLine "Waiting for login..."
#Wait-Job $loginJob

while ($(Get-Job -Id $loginJobId).State -eq 'Running') {
  Write-Host -NoNewLine "."
  Start-Sleep -Seconds 10
}
Write-Host

if ((Get-Job -Id $loginJobId -IncludeChildJob | Where-Object {$_.Error} | Select-Object -ExpandProperty Error) -or ((Get-Job -Id $loginJobId).State -eq 'Failed'))
{
  $loginFailMsg = "Login failed, please see the log for additional details."

  Write-Host $loginFailMsg
  Show-Message 'Azure Arc-enabled SQL Server' $loginFailMsg 'Warning' 'Ok'
  Stop-Transcript

  Stop-Process -Id $edge.Id -ErrorAction SilentlyContinue
  throw [System.Exception] "Login Failed!"
}

Stop-Process -Id $edge.Id -ErrorAction SilentlyContinue
Write-Host "Login Success!"

# Set Subscription Context
Invoke-Command -Session $Server01 -ScriptBlock {Set-AzContext -Subscription $using:subId}

# Verify user permissions
$userName = Invoke-Command -Session $Server01 -ScriptBlock {$(Get-AzADUser -SignedIn).DisplayName}
$userObjectId = Invoke-Command -Session $Server01 -ScriptBlock {$(Get-AzADUser -SignedIn).Id}
$roleWritePermissions = Invoke-Command -Session $Server01 -ScriptBlock {Get-AzRoleAssignment -ResourceGroupName $using:resourceGroup -WarningAction SilentlyContinue}
$actionList = @("*", "Microsoft.Authorization/*/Write")
$roleDefId = Invoke-Command -Session $Server01 -ScriptBlock {@(Get-AzRoleDefinition | Where-Object { (Compare-Object $using:actionList $_.Actions -IncludeEqual -ExcludeDifferent) -and -not (Compare-Object $using:actionList $_.NotActions -IncludeEqual -ExcludeDifferent) } | Select-Object -ExpandProperty Id)}
$hasPermission = @($roleWritePermissions | Where-Object { $_.ObjectId -eq $userObjectId } | Where-Object { $roleDefId -contains $_.RoleDefinitionId })

if(-not $hasPermission) {
  $permissionFailMsg = "User ($userName) missing 'write' permissions to Resource Group '${resourceGroup}'. Please see the log for additional details."

  Write-Host $permissionFailMsg
  Show-Message 'Azure Arc-enabled SQL Server' $permissionFailMsg 'Warning' 'Ok'
  Stop-Transcript

  throw [System.Exception] "Invalid user permissions on Resource Group!"
}

Write-Host "User ($userName) has 'write' permissions to Resource Group '${resourceGroup}'!"

# Onboard Azure Arc-enabled SQL Server

$sqlJob = Invoke-Command -Session $Server01 -FilePath $scriptLocation\installArcAgentSQLUser.ps1 -AsJob

$sqlJobId = $sqlJob.Id

Write-Host "Target SQL Server -> ${sqlServerName}"
Write-Host -NoNewLine "Onboarding..."
# Wait-Job $sqlJob

while ($(Get-Job -Id $sqlJobId).State -eq 'Running') {
  Write-Host -NoNewLine "."
  Start-Sleep -Seconds 10
}
Write-Host

if ((Get-Job -Id $sqlJobId -IncludeChildJob | Where-Object {$_.Error} | Select-Object -ExpandProperty Error) -or ((Get-Job -Id $sqlJobId).State -eq 'Failed'))
{
  $onboardFailMsg = "SQL Server Onboading failed, please see the log for additional details."

  Write-Host $onboardFailMsg
  Show-Message 'Azure Arc-enabled SQL Server' $onboardFailMsg 'Warning' 'Ok'
  Stop-Transcript

  throw [System.Exception] "Login Failed!"
}

$onboardSuccessMsg = "SQL Server has been successfully onboaded into Azure Arc! The server should be visible in the Arc blade of the Azure portal in the next few minutes."

Write-Host "SQL Server Onboarded!"
Show-Message 'Azure Arc-enabled SQL Server' $onboardSuccessMsg 'None' 'Ok'

$shortcutLink = "$Env:Public\Desktop\Onboard SQL Server.lnk"
Remove-Item $shortcutLink -Force

Stop-Transcript
