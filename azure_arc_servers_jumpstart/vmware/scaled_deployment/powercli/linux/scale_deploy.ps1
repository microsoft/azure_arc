# Define Variables
# Connet to VMware vCenter
Invoke-Expression ".\vars.ps1"
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
Connect-VIServer -Server $env:vCenterAddress -User $env:vCenterUser -Password $env:vCenterUserPassword -Force # vars are defined in vars.ps1
$VMs = Get-Folder -Name $env:VMFolder | Get-VM # VMFolder is defined in vars.ps1

ForEach ($VMName in $VMs) {
  $VM = Get-VM $VMName

  $File1 = "vars.sh" # vars.sh is auto-generated
  $sCopy1 = @{
    Source = $env:SrcPath + $File1 # SrcPath defined in vars.ps1
    Destination = "/tmp/arctemp/"
    VM = $VM
    LocalToGuest = $true
    GuestUser = "$env:OSAdmin" # OSAdmin defined in vars.ps1
    GuestPassword = "$env:OSAdminPassword" # OSAdminPassword defined in vars.ps1
    Verbose = $false
  }

  $File2 = "install_arc_agent.sh"
  $sCopy2 = @{
    Source = $env:SrcPath + $File2 # SrcPath defined in vars.ps1
    Destination = "/tmp/arctemp/"
    VM = $VM
    LocalToGuest = $true
    GuestUser = "$env:OSAdmin" # OSAdmin defined in vars.ps1
    GuestPassword = "$env:OSAdminPassword" # OSAdminPassword defined in vars.ps1
    Verbose = $false
  }

  # Onboarding VM to Azure Arc
  Write-Host "Hold tight, I am onboarding $VMName Virtual Machine to Azure Arc..." -ForegroundColor Cyan
  Copy-VMGuestFile @sCopy1 -Force
  Copy-VMGuestFile @sCopy2 -Force
  $Result = Invoke-VMScript -VM $VM -ScriptText "sudo bash /tmp/arctemp/install_arc_agent.sh" -GuestUser $env:OSAdmin -GuestPassword $env:OSAdminPassword
  $ExitCode = $Result.ExitCode
  if ($ExitCode = "0") {
    Write-Host $VMName is now successfully onboarded to Azure Arc -ForegroundColor Green
  }
  Else {
    Write-Host $VMName returned exit code $ExitCode -ForegroundColor Red
  }

  # Cleaning garbage
  $Delete = Invoke-VMScript -VM $VM -ScriptText "rm -rf /tmp/arctemp/" -GuestUser $env:OSAdmin -GuestPassword $env:OSAdminPassword
}
