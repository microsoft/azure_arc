param(
    [string]$subId = "<subscriptionId>",
    [string]$resourceGroup = "<resourceGroup>",
    [string]$sqlServerName = "<sqlServerName>"
)

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
This script will onboard the VM 'ArcBox-SQL' as an Arc-enabled SQL Server.

When you click 'OK', you will be redirected to the Micorsoft Device Authentication website. The code will be copied to the clipboard, so simply paste it in and complete the Microsoft authentication process.

To continue, you must be an Owner or User Access Administrator at the Subscription or Resource Group level.
"@

$continue = Show-Message 'Arc-enabled SQL Server' $startMsg 'Asterisk' 'OkCancel'

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

Write-Host "Copying Arc-enabled SQL onboarding script to ${sqlServerName}.."

Copy-Item –Path $scriptLocation\SQL.ps1 –Destination $scriptLocation –ToSession $Server01 -Force

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

$edge = Start-Process 'https://www.microsoft.com/devicelogin' -PassThru

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
  Show-Message 'Arc-enabled SQL Server' $loginFailMsg 'Warning' 'Ok'
  Stop-Transcript

  throw [System.Exception] "Login Failed!"
}

Write-Host "Login Success!"

# Verify user permissions

$user = Invoke-Command -Session $Server01 -ScriptBlock {$(Get-AzADUser -SignedIn ).UserPrincipalName}

$roleWritePermissions = Invoke-Command -Session $Server01 -ScriptBlock {Get-AzRoleAssignment -Scope "/subscriptions/${using:subId}/resourcegroups/${using:resourceGroup}/providers/Microsoft.Authorization/roleAssignments/write" -WarningAction SilentlyContinue}

$hasPermission = $roleWritePermissions | Where-Object {$_.SignInName -eq $user}

if(-not $hasPermission) {
  $permissionFailMsg = "User ($user) missing 'write' permissions to Resource Group '${resourceGroup}'. Please see the log for additional details."

  Write-Host $permissionFailMsg
  Show-Message 'Arc-enabled SQL Server' $permissionFailMsg 'Warning' 'Ok'
  Stop-Transcript

  throw [System.Exception] "Invalid user permissions on Resource Group!"
}

Write-Host "User ($user) has 'write' permissions to Resource Group '${resourceGroup}'!"

# Onboard Arc-enabled SQL Server

$sqlJob = Invoke-Command -Session $Server01 -FilePath $scriptLocation\SQL.ps1 -AsJob

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
  Show-Message 'Arc-enabled SQL Server' $onboardFailMsg 'Warning' 'Ok'
  Stop-Transcript

  throw [System.Exception] "Login Failed!"
}

$onboardSuccessMsg = "SQL Server has been successfully onboaded into Azure Arc! The server should be visible in the Arc blade of the Azure portal in the next few minutes."

Write-Host "SQL Server Onboarded!"
Show-Message 'Arc-enabled SQL Server' $onboardSuccessMsg 'None' 'Ok'

Stop-Transcript
