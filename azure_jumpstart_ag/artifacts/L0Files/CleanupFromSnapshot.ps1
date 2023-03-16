# Script runtime environment: Level-0 Azure virtual machine ("Client VM")

#######################################
# Script for reseting the environment #
#######################################

# Create an array with VM names    
$VMnames = (Get-VM).Name

# Restore back the virtual machine based on original snapshot created in logon script
foreach ($VMName in $VMNames) {
    Restore-VMSnapshot -Name "Base" -VMName $VMName -Confirm:$false
    Start-VM -Name $VMName
}

# Delete all files and folders for .kube folder on L0 virtual machine
Remove-Item -Path "$env:USERPROFILE\.kube\*" -Recurse -Force
