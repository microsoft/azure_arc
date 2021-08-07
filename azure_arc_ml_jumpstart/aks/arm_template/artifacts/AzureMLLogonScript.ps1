Start-Transcript -Path C:\Temp\AzureMLLogonScript.log

# Deployment environment variables
$connectedClusterName = "Arc-AML-AKS"

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Login as service principal
az login --service-principal --username $env:spnClientId --password $env:spnClientSecret --tenant $env:spnTenantId

# Set default subscription
az account set --subscription $env:subscriptionId

# Registering Azure Arc providers
Write-Host "Registering Azure Arc providers, hold tight..."
Write-Host "`n"
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

az provider show --namespace Microsoft.Kubernetes -o table
Write-Host "`n"
az provider show --namespace Microsoft.KubernetesConfiguration -o table
Write-Host "`n"
az provider show --namespace Microsoft.ExtendedLocation -o table
Write-Host "`n"

# Adding Azure Arc CLI extensions
Write-Host "Adding Azure Arc CLI extensions"
Write-Host "`n"
az config set extension.use_dynamic_install=yes_without_prompt

Write-Host "`n"
az -v

# Getting AKS cluster credentials kubeconfig file
Write-Host "Getting AKS cluster credentials"
Write-Host "`n"
az aks get-credentials --resource-group $env:resourceGroup `
                       --name $env:clusterName --admin

Write-Host "Checking kubernetes nodes"
Write-Host "`n"
kubectl get nodes
Write-Host "`n"

# Onboarding the AKS cluster as an Azure Arc enabled Kubernetes cluster
Write-Host "Onboarding the cluster as an Azure Arc enabled Kubernetes cluster"
Write-Host "`n"

# Monitor pods across namespaces
$kubectlMonShell = Start-Process -PassThru PowerShell {for (0 -lt 1) {kubectl get pods --all-namespaces; Start-Sleep -Seconds 15; Clear-Host }}
$kubectlWatchShell = Start-Process -PassThru PowerShell {kubectl get pods --all-namespaces -w}

# Create Kubernetes - Azure Arc Cluster
az connectedk8s connect --name $connectedClusterName `
                        --resource-group $env:resourceGroup `
                        --location $env:azureLocation `
                        --tags 'Project=jumpstart_azure_arc_ml_services' `
						      --custom-locations-oid '51dfe1e8-70c6-4de5-a08e-e18aff23d815'
                        # This is the Custom Locations Enterprise Application ObjectID from AAD

Start-Sleep -Seconds 10

###################################################################################################################
# Azure Arc-enabled Machine Learning enablement components
Write-Host """
 Enabling Azure Arc-enabled Machine Learning enablement components:

                 /((((((((#,
                 /(((((((##,
                 (((#######,
                 (#########,
                 (#########,
                 (#########,
                 ((((((((((
              /((((((((((    (/
            ((((((((((/    ((((((
          ((((((((((,    ###((((###
       .///(((((((.     /############
     ,//////((((           ############*
    **//////((%%%%%%%%%%%%%%%############
    *///////&&&%%%%%%%%%%%%%%%%&########,
     /////&&&&&&%%%%%%%%%%%%%&&&&&######
      /(&&&&&&&&&&%&%%%%%%&&&&&&&&&&&##
      
"""

# Adding Azure ML CLI extension
az extension add -n ml
az ml -h

# Set AML workspace defaults
$random = ((New-Guid).Guid).Split('-')[0]
$ws = "arcaml-$random-ws" # AML workspace name
az configure --defaults workspace=$ws group=$env:resourceGroup

# Create Azure ML workspace
az ml workspace create -g $env:resourceGroup

########################################################################################################
# Functions
########################################################################################################

# Install the aml-arc-compute extension - with Training and Inferencing
function Install-aml-extension {
   Param ([string]$connectedClusterName)

   az k8s-extension create --name amlarc-compute `
                           --extension-type Microsoft.AzureML.Kubernetes `
                           --cluster-type connectedClusters `
                           --cluster-name $connectedClusterName `
                           --resource-group $env:resourceGroup `
                           --scope cluster `
                           --configuration-settings enableTraining=True enableInference=True allowInsecureConnections=True inferenceLoadBalancerHA=False # This is since our K8s is 1 node
   return 1
}

# Get the extension install status from ARM
function Get-ExtensionStatusARM {
   Param ([string]$extension, [string]$connectedClusterName)

   $response = az k8s-extension show --name $extension `
                                        --cluster-type connectedClusters `
                                        --cluster-name $connectedClusterName `
                                        --resource-group $env:resourceGroup `
                                        --output json | ConvertFrom-Json
   return $response
}

# Get the extension install status from Helm
function Get-ExtensionStatusHelm {
   Param ([string]$chart)

   $response = helm list --filter $chart -A -a -o json | ConvertFrom-Json
   
   return $response
}
########################################################################################################
# Initiate the extension install
Write-Host "Installing amlarc-compute K8s extension..." -ForegroundColor Yellow
Install-aml-extension -connectedClusterName $connectedClusterName

# Loop until install is successful on both ARM and Helm
Do 
{  
   # Get ARM response
   $ARMresponse = Get-ExtensionStatusARM -extension "amlarc-compute" -connectedClusterName $connectedClusterName
   Write-Host ("ARM Status: ", $ARMresponse.installState)

   # Get Helm response
   $Helmresponse = Get-ExtensionStatusHelm -chart "amlarc-compute"
   Write-Host ("Helm Status: ", $Helmresponse.status)

   Start-Sleep -Seconds 15
} while (($ARMresponse.installState -ne "Installed") -and ($Helmresponse.status -ne "deployed"))

Write-Host "Installing amlarc-compute K8s extension was successful." -ForegroundColor Green

# Get Arc Cluster Resource ID
$connectedClusterId = az connectedk8s show --name $connectedClusterName --resource-group $env:resourceGroup --query id -o tsv

# Replace staging values in Python Script
# 1.Get_WS.py
$Script = "C:\Temp\1.Get_WS.py"
(Get-Content -Path $Script) -replace 'subscription_id-stage',$env:subscriptionId | Set-Content -Path $Script
(Get-Content -Path $Script) -replace 'resource_group-stage',$env:resourceGroup | Set-Content -Path $Script
(Get-Content -Path $Script) -replace 'workspace_name-stage',$ws | Set-Content -Path $Script

# 2.Attach_Arc.py
$Script = "C:\Temp\2.Attach_Arc.py"
(Get-Content -Path $Script) -replace 'connectedClusterName-stage',$connectedClusterName | Set-Content -Path $Script
(Get-Content -Path $Script) -replace 'connectedClusterId-stage',$connectedClusterId | Set-Content -Path $Script

# Set Azure ML default Workspace info
python "C:\Temp\1.Get_WS.py"

# Attach Arc Cluster to Azure ML Workspace
python "C:\Temp\2.Attach_Arc.py"

#################
# Training Model
#################
Write-Host """
 Training model:                                           
            .....                                             .....             
         .........                                           .........          
        .........                 (((((((((##                 .........         
       .....                      (((((((####                      .....        
      ......                      #((########                      ......       
     ....... .............        ###########        ............. .......      
     ......................       ###########       ......................      
    .................*.....       ###########       ....,*.................     
    .........*******......       (((((((((((         ......*******.........     
         ............          (((((((((((     (.         ............          
                            .(((((((((((     (((((/                             
                          ((((((((((((     #(((((((##                           
                        ////(((((((*     ##############                         
                      //////(((((.         ,#############.                      
                   ,**///////((               #############/                    
                    *////////&%%%%%%%%%%%%%%%%%%%##########                     
                    ///////&&&%&%%%%%%%%%%%%%%%&%&&#######(                     
                     ////&&&&&&&%%%%%%%%%%%%%&&&&&&&&%####                      
                     .(&&&&&&&&&&&&&&%%%%%%&&&&&&&&&&&&&#.                      
                                                                         
                     ████████╗██████╗░░█████╗░██╗███╗░░██╗
                     ╚══██╔══╝██╔══██╗██╔══██╗██║████╗░██║
                     ░░░██║░░░██████╔╝███████║██║██╔██╗██║
                     ░░░██║░░░██╔══██╗██╔══██║██║██║╚████║
                     ░░░██║░░░██║░░██║██║░░██║██║██║░╚███║
                     ░░░╚═╝░░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚══╝
"""
# Replace staging values
$JobFile = "C:\Temp\simple-train-cli\job.yml"
(Get-Content -Path $JobFile) -replace 'connectedClusterName-stage',$connectedClusterName | Set-Content -Path $JobFile

# Create MNIST Dataset and register against Workspace
python "C:\Temp\3.Create_MNIST_Dataset.py"

# Train model with AML CLI
$Job = az ml job create -f $JobFile
$RunId = ($Job | grep '\"name\":').Split('\"')[3]

# Poll training status from ARM
Write-Host "Training model, hold tight..."
Do 
{
   $response = az ml job show --name $RunId --query "{Name:name,Jobstatus:status}" | ConvertFrom-Json
   Write-Host ("Job Status: ", $response.Jobstatus)

	If ($response.Jobstatus -eq "Canceled") {break}

	Start-Sleep -Seconds 20

} while (($response.Jobstatus -ne "Completed") -and ($response.Jobstatus -ne "Canceled"))

# Flag for Training Status
$TrainingStatus = "Unsuccessful"

# Get Job status
If ($response.Jobstatus -eq "Completed"){
   Write-Host "Job completed." -ForegroundColor Green
   # Download job artifacts, including pkl model
   az ml job download -n $RunId --outputs --download-path "C:\Temp"
   # Set flag for successful training
   $TrainingStatus = "Successful"
}
elseif ($response.Jobstatus -eq "Canceled"){
	Write-Host "Job was canceled." -ForegroundColor Yellow
}
else
{
    Write-Host "Something else went wrong."
}

#######################
# Inference Deployment
#######################
Write-Host """
 Deploying model to Kubernetes Cluster:                                           
                                                                                                                                  
                                    .,,,,                                       
                                  ,,,,,,,,,                                     
                                  ,,,,,,,,,                                     
                                *//,,,,,,,*,,,,                                 
                            ///////////////////,,,,,                            
              ,,,,,,,  /////////////////////////////,,,,,,,,,,,                 
             ,,,,,,,,,/////////////////////////////////,,,,,,,,,                
              ,,,,,,,,///////////////////////////////,,,,,,,,,,,                
                 ,,#######//////////////////////*,,,,#####(,                    
                 ,,############/////*,,,,///,,,,*##########,                    
                 ,,###############,,,,,,,,,,###############,                    
                 ,,###############,,,,,,,,,################,                    
                 ,,################*,,,,,,#################,                    
                 ,,##################/,,###################,                    
                 ,,##################/,,###################,                    
              ,,,,,,,################/,,################,,,,,,,                 
             ,,,,,,,,,###############/,,###############,,,,,,,,,                
             .,,,,,,,,,,#############/,,###############,,,,,,,,,                
                 ,,     ,,,,/########/,,###########       .,.                   
                            .,,,,###/,,,*#####.                                 
                                 ,,,,,,,,,,                                     
                                  ,,,,,,,,,                                     
                                   ,,,,,,,                                                                                                           
                                   
               ██████╗░███████╗██████╗░██╗░░░░░░█████╗░██╗░░░██╗
               ██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗╚██╗░██╔╝
               ██║░░██║█████╗░░██████╔╝██║░░░░░██║░░██║░╚████╔╝░
               ██║░░██║██╔══╝░░██╔═══╝░██║░░░░░██║░░██║░░╚██╔╝░░
               ██████╔╝███████╗██║░░░░░███████╗╚█████╔╝░░░██║░░░
               ╚═════╝░╚══════╝╚═╝░░░░░╚══════╝░╚════╝░░░░╚═╝░░░
"""
# Replace staging values
$JobFile = "C:\Temp\simple-inference-cli\endpoint.yml"
(Get-Content -Path $JobFile) -replace 'connectedClusterName-stage',$connectedClusterName | Set-Content -Path $JobFile

# Flag for Inference Status
$InferenceStatus = "Unsuccessful"

# Proceed with inference deployment only if training was successful
If ($TrainingStatus -eq "Successful"){
   Write-Host "Copying trained model pkl to deployment folder..." -ForegroundColor White
   Copy-Item "C:\Temp\$RunId\outputs\*.pkl" -Destination "C:\Temp\simple-inference-cli\model"

   # Deploy unique inference endpoint
   $random = ((New-Guid).Guid).Split('-')[0]
   $name = "sklearn-mnist-$random"

   # Synchronous call (blocking) - 5-10 minutes
   Write-Host "Creating model deployment on your K8s cluster, takes 5-10 minutes..." -ForegroundColor White
   az ml endpoint create -n $name -f $JobFile

   # Set flag
   $InferenceStatus = "Successful"
}
else
{
    Write-Host "Training was not successful - Inference skipped."
}

#################
# Inference Call
#################

$RequestFile = "C:\Temp\simple-inference-cli\sample-request.json"

# Proceed with inference call only if inference deployment was successful
If ($InferenceStatus -eq "Successful"){
   # Method 1: One-line invoke model
   Write-Host "Method 1: Calling deployed model using az ml endpoint" -ForegroundColor Yellow
   Write-Host "The sample request represents the following numeral:" -ForegroundColor White
   az ml endpoint invoke -n $name -r $RequestFile

   # Method 2: Call using PowerShell Invoke-RestMethod (for demonstration)
   Write-Host "Method 2: Calling deployed model using PowerShell Direct REST API call" -ForegroundColor Yellow
   # Get OAuth token
   $token = $(az ml endpoint get-credentials --name $name `
                                             --resource-group $env:resourceGroup `
                                             --workspace-name $ws | ConvertFrom-Json).accessToken
   # Get scoring URL
   $scoring_uri = $(az ml endpoint show --name $name `
                                        --resource-group $env:resourceGroup `
                                        --workspace-name $ws | ConvertFrom-Json).scoring_uri

   Write-Host "Model Scoring URL: $scoring_uri" -ForegroundColor White
   
   # Score using URL
   $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
   $headers.Add("Authorization", "Bearer $token")
   $headers.Add("Content-Type", "application/json")
   $body = Get-Content $RequestFile | Out-String

   Write-Host "The sample request represents the following numeral:" -ForegroundColor White
   $response = Invoke-RestMethod $scoring_uri -Method 'POST' -Headers $headers -Body $body
   $response | ConvertTo-Json
}
else
{
    Write-Host "Training and/or Inference was not successful - call skipped."
}

###################################################################################################################

# Changing to Client VM wallpaper
$imgPath="C:\Temp\wallpaper.png"
$code = @' 
using System.Runtime.InteropServices; 
namespace Win32{ 
    
     public class Wallpaper{ 
        [DllImport("user32.dll", CharSet=CharSet.Auto)] 
         static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ; 
         
         public static void SetWallpaper(string thePath){ 
            SystemParametersInfo(20,0,thePath,3); 
         }
    }
 } 
'@

add-type $code 
[Win32.Wallpaper]::SetWallpaper($imgPath)

# Kill the open PowerShell monitoring kubectl get pods
Stop-Process -Id $kubectlMonShell.Id
Stop-Process -Id $kubectlWatchShell.Id

# Removing the LogonScript Scheduled Task so it won't run on next reboot
Unregister-ScheduledTask -TaskName "AzureMLLogonScript" -Confirm:$false
Start-Sleep -Seconds 5

# We intentionally keep the script running, so we have a chance to see the predictions
# Stop-Process -Name powershell -Force
# Stop-Transcript