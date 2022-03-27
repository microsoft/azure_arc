#!/bin/bash
exec >globalConfig.log
exec 2>&1

# Declaring the deployment environment (Production/Dev)
export deploymentEnvironment="$(echo $templateBaseUrl | grep "microsoft/azure_arc/main")"

# Declaring if this is a Jumpstart scenario or ArcBox deployment
if [ -z "$flavor" ]
then
    export jumpstartDeployment="Jumpstart scenario"
else
    export jumpstartDeployment="Jumpstart ArcBox"
fi

# Setting up the environment variable for the Jumpstart App Configuration connection string deployment (Production/Dev)
export jumpstartAppConfigProduction='Endpoint=https://jumpstart-prod.azconfig.io;Id=xcEf-l6-s0:Fn+IoFEzNKvm/Bo0+W1I;Secret=dkuO3eUhqccYw6YWkFYNcPMZ/XYQ4r9B/4OhrWTLtL0='
export jumpstartAppConfigDev='Endpoint=https://jumpstart-dev.azconfig.io;Id=5xh8-l6-s0:q89J0MWp2twZnTsqoiLQ;Secret=y5UFAWzPNdJsPcRlKC538DimC4/nb1k3bKuzaLC90f8='

if [ -z "$deploymentEnvironment" ]
then
    # export appconfig_connection_string=$jumpstartAppConfigProduction
    az configure --defaults appconfig_connection_string=$jumpstartAppConfigProduction
    deploymentEnvironment="Production"
    echo ""
    echo This is a "$jumpstartDeployment" "$deploymentEnvironment" deployment!
else
    # export appconfig_connection_string=$jumpstartAppConfigDev
    az configure --defaults appconfig_connection_string=$jumpstartAppConfigDev
    deploymentEnvironment="Dev"
    echo ""
    echo This is a "$jumpstartDeployment" "$deploymentEnvironment" deployment!
fi

# Declaring required Azure Arc resource providers
export providersArcKubernetes="$(az appconfig kv list --key "providersArcKubernetes" --label "$deploymentEnvironment" --query "[].value" -o tsv)"
export providersArcDataSvc="$(az appconfig kv list --key "providersArcDataSvc" --label $deploymentEnvironment --query "[].value" -o tsv)"
export providersArcAppSvc="$(az appconfig kv list --key "providersArcAppSvc" --label $deploymentEnvironment --query "[].value" -o tsv)"
export allArcProviders="$($providersArcKubernetes + $providersArcDataSvc + $providersArcAppSvc)"

# Declaring required Azure Arc Azure CLI extensions
export kubernetesExtensions="$(az appconfig kv list --key "kubernetesExtensions" --label $deploymentEnvironment --query "[].value" -o tsv)"
export dataSvcExtensions="$(az appconfig kv list --key "dataSvcExtensions" --label $deploymentEnvironment --query "[].value" -o tsv)"
export appSvcExtensions="$(az appconfig kv list --key "appSvcExtensions" --label $deploymentEnvironment --query "[].value" -o tsv)"




# Declaring required Azure Arc resource providers
export providersArcKubernetes="$(az appconfig kv list --key "providersArcKubernetes" --label "$deploymentEnvironment" --query "[].value" -o tsv)"
export providersArcDataSvc="$(az appconfig kv list --key "providersArcDataSvc" --label $deploymentEnvironment --query "[].value" -o tsv)"
export providersArcAppSvc="$(az appconfig kv list --key "providersArcAppSvc" --label $deploymentEnvironment --query "[].value" -o tsv)"
export allArcProviders="$($providersArcKubernetes + $providersArcDataSvc + $providersArcAppSvc)"

# Declaring required Azure Arc Azure CLI extensions
export kubernetesExtensions="$(az appconfig kv list --key "kubernetesExtensions" --label $deploymentEnvironment --query "[].value" -o tsv)"
export dataSvcExtensions="$(az appconfig kv list --key "dataSvcExtensions" --label $deploymentEnvironment --query "[].value" -o tsv)"
export appSvcExtensions="$(az appconfig kv list --key "appSvcExtensions" --label $deploymentEnvironment --query "[].value" -o tsv)"

az appconfig kv list --key "providersArcKubernetes" --label "$deploymentEnvironment" --query "[].value" -o tsv | sed 's/Kubernetes/Lior/g'


providersArcKubernetes=`az appconfig kv list --key "providersArcKubernetes" --label "$deploymentEnvironment" --query "[].value" -o tsv`

IFS='^M\n'
for provider in $providersArcKubernetes
do
      echo  The name of the provider is $provider
done
