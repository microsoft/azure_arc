#!/bin/bash
exec >globalConfig.log
exec 2>&1

# Declaring the deployment environment (Production/Dev)
$templateBaseUrl="https://raw.githubusercontent.com/microsoft/azure_arc/main/azure_jumpstart_arcbox/ARM/"
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
    az configure --defaults appconfig_connection_string=$jumpstartAppConfigProduction
    deploymentEnvironment="Production"
    echo ""
    echo This is a "$jumpstartDeployment" "$deploymentEnvironment" deployment!
else
    az configure --defaults appconfig_connection_string=$jumpstartAppConfigDev
    deploymentEnvironment="Dev"
    echo ""
    echo This is a "$jumpstartDeployment" "$deploymentEnvironment" deployment!
fi

# Declaring required Azure Arc resource providers
export providersArcKubernetes="$(az appconfig kv list --key "providersArcKubernetes" --label $deploymentEnvironment --query "[].value" -o tsv)"
export providersArcDataSvc=$(az appconfig kv list --key "providersArcDataSvc" --label $deploymentEnvironment --query "[].value" -o tsv)
export providersArcAppSvc="$(az appconfig kv list --key "providersArcAppSvc" --label $deploymentEnvironment --query "[].value" -o tsv)"
# export allArcProviders=${providersArcKubernetes}${providersArcDataSvc}+${providersArcAppSvc}

# Declaring required Azure Arc Azure CLI extensions
export kubernetesExtensions="$(az appconfig kv list --key "kubernetesExtensions" --label $deploymentEnvironment --query "[].value" -o tsv)"
export dataSvcExtensions="$(az appconfig kv list --key "dataSvcExtensions" --label $deploymentEnvironment --query "[].value" -o tsv)"
export appSvcExtensions="$(az appconfig kv list --key "appSvcExtensions" --label $deploymentEnvironment --query "[].value" -o tsv)"

export providersArcKubernetes=`readarray -t a < $providersArcKubernetes`

export providersArcKubernetesNew=`echo "$providersArcKubernetes" | tr -d '"'`

providersArcKubernetes=$(cat providers.env)
# providersArcKubernetes=`echo "$providersArcKubernetesNew" | tr -d '"'`
providersArcKubernetes=`sed -e 's/^"//' -e 's/"$//' <<<"$providersArcKubernetes"`

providersArcKubernetes=($(cat providers.env))
providersArcKubernetes=$(mapfile -t array < <(./providers.sh))
providersArcKubernetes=($(./providers.sh))
mapfile -t array < <(./providers.sh)




az appconfig kv list --key "providersArcKubernetes" --label $deploymentEnvironment --query "[].value" -o tsv > global.env
sed 's/\"//g' global.env > global.txt


# Register-ArcKubernetesProviders () {
# filename="global.txt"
# providersArcKubernetes="$(cat $filename)"
# for provider in $providersArcKubernetes
#     do
#         registrationState="$(az provider show --namespace "$provider" --query registrationState -o tsv)"
#     done
#     if [ "$registrationState" == "Registered" ]; then
#         echo "$provider" Azure resource provider is already registered
#     else
#         echo ""
#         echo "$provider" Azure resource provider is not registered. Registering, hold tight...
#         az provider register --namespace "$provider"
#     while [ "$registrationState" != "Registered" ]
#     do
#         sleep 5
#         echo "$provider" Azure resource provider is still regitering, hold tight...
#         registrationState=$(az provider show --namespace "$provider" --query registrationState -o tsv)
#     done
#         echo "$provider" Azure resource provider is now registered
#         echo ""
# fi
# }


Register-ArcKubernetesProviders () {
# filename="global.txt"
# providersArcKubernetes="$(cat $filename)"
for provider in $providersArcKubernetes
    do
        registrationState=`az provider show --namespace "$provider" --query registrationState -o tsv`
        echo $provider
    done
    if [ "$registrationState" == "Registered" ]; then
        echo "$provider" Azure resource provider is already registered!
    else
        echo ""
        echo "$provider" Azure resource provider is not registered. Registering, hold tight...
        az provider register --namespace "$provider"
    while [ "$registrationState" != "Registered" ]
    do
        sleep 5
        echo "$provider" Azure resource provider is still regitering, hold tight...
        registrationState=$(az provider show --namespace "$provider" --query registrationState -o tsv)
    done
        echo "$provider" Azure resource provider is now registered?
        echo ""
fi
}


providersArcKubernetes=("Microsoft.Kubernetes" "Microsoft.KubernetesConfiguration" "Microsoft.ExtendedLocation")










Register-ArcKubernetesProviders () {
for provider in ${providersArcKubernetes[@]}
    do
        echo $provider
        registrationState="$(az provider show --namespace $provider --query registrationState -o tsv)"
    done
    if [ "$registrationState" == "Registered" ]; then
        echo "$provider" Azure resource provider is already registered
    else
        echo ""
        echo "$provider" Azure resource provider is not registered. Registering, hold tight...
        az provider register --namespace "$provider"
    while [ "$registrationState" != "Registered" ]
    do
        sleep 5
        echo "$provider" Azure resource provider is still regitering, hold tight...
        registrationState=$(az provider show --namespace "$provider" --query registrationState -o tsv)
    done
        echo "$provider" Azure resource provider is now registered
        echo ""
fi
}


Register-ArcKubernetesProviders () {
filename="global.txt"
# providersArcKubernetes=$(cat $filename)
for provider in $(cat $filename)
    do
        echo $provider
        az provider show --namespace $provider --query registrationState -o tsv
    done
}
