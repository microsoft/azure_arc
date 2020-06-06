#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -a \$LOCATION -b \$RESOURCEGROUP -c \$AROCLUSTER -d \$ARC -e \$SPClientId -f \$SPClientSecret -g \$TenantID"
   echo -e "\t-a Location of where you want to deploy"
   echo -e "\t-b Name of the Resource Group"
   echo -e "\t-c Name of the Azure Redshift Openshift Cluster Name "
   echo -e "\t-d Name of the Azure Arc Kubernetes Cluster Name"
   echo -e "\t-e This is the Service Principal appId or client ID"
   echo -e "\t-f This is the Service Principal client secret"
   echo -e "\t-g This is the tenant ID for the Service Prinipal"        
   exit 1 # Exit script after printing help
}


while getopts "a:b:c:d:e:f:g:" opt
do
   case "$opt" in
      a ) LOCATION="$OPTARG" ;;
      b ) RESOURCEGROUP="$OPTARG" ;;
      c ) AROCLUSTER="$OPTARG" ;;
      d ) ARC="$OPTARG" ;;
      e ) SPClientId="$OPTARG" ;;
      f ) SPClientSecret="$OPTARG" ;;
      g ) TenantID="$OPTARG" ;;      
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$LOCATION" ] || [ -z "$RESOURCEGROUP" ] || [ -z "$AROCLUSTER" ] || [ -z "$ARC" ] || [ -z "$SPClientId" ] || [ -z "$SPClientSecret" ] || [ -z "$TenantID" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

# Begin script in case all parameters are correct
/usr/local/bin/az login --service-principal -u $SPClientId -p $SPClientSecret --tenant $TenantID