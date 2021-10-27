Start-Transcript -Path C:\ArcBox\DeploymentStatus.log

# Sending deployement status message to Azure storage account queue
$arcNumResources = az graph query -q "Resources | where type =~ 'Microsoft.HybridCompute/machines' or type=~'Microsoft.Kubernetes/connectedClusters' or type=~'Microsoft.AzureArcData/SqlServerInstances' or type=~'Microsoft.AzureArcData/dataControllers' or type=~'Microsoft.AzureArcData/sqlManagedInstances' or type=~'Microsoft.AzureArcData/postgresInstances' | where resourceGroup=~'$env:resourceGroup' | where tags.Project=~'jumpstart_arcbox' | project name, location, resourceGroup, tags | summarize count()" | Select-String "count_"
$arcNumResources = $arcNumResources -replace "[^0-9]" , ''
Write-Host "You now have $arcNumResources Azure Arc resources in '$env:resourceGroup' resource group"
Write-Host "`n"

# ArcBox Full edition report if applicabale
if ($env:flavor -eq "Full" -Or $env:flavor -eq "Developer") {
    if ( $arcNumResources -eq 11 )
    {
        Write-Host "Great success!"
        az storage message put --content "Successful Jumpstart ArcBox ($env:flavor) deployment" --account-name "jumpstartusage" --queue-name "arcboxusage" --sas-token "?sv=2020-08-04&ss=q&srt=sco&sp=wa&se=2031-11-01T07:34:50Z&st=2021-10-18T23:34:50Z&spr=https&sig=tQMbCj5EthrwachHMuzLSJ4SgSOtEqqWcAbid6b87vU%3D" --time-to-live -1
    }
}

# ArcBox IT Pro edition report if applicabale
if ($env:flavor -eq "ITPro") {
    if ( $arcNumResources -eq 6 )
    {
        Write-Host "Great success!"
        az storage message put --content "Successful Jumpstart ArcBox ($env:flavor) deployment" --account-name "jumpstartusage" --queue-name "arcboxusage" --sas-token "?sv=2020-08-04&ss=q&srt=sco&sp=wa&se=2031-11-01T07:34:50Z&st=2021-10-18T23:34:50Z&spr=https&sig=tQMbCj5EthrwachHMuzLSJ4SgSOtEqqWcAbid6b87vU%3D" --time-to-live -1
    }
}

if ( $arcNumResources -cne 11 -and $arcNumResources -cne 6) {
    Write-Host "Too bad, not all Azure Arc resources onboarded"
    az storage message put --content "Failed Jumpstart ArcBox ($env:flavor) deployment" --account-name "jumpstartusage" --queue-name "arcboxusage" --sas-token "?sv=2020-08-04&ss=q&srt=sco&sp=wa&se=2031-11-01T07:34:50Z&st=2021-10-18T23:34:50Z&spr=https&sig=tQMbCj5EthrwachHMuzLSJ4SgSOtEqqWcAbid6b87vU%3D" --time-to-live -1
}
