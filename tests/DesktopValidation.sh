#!/bin/bash
resourceGroup=${1}
flavor=${2}
deployTestParametersFile=${3}
windowsAdminUsername=${4}
windowsAdminSecret=${5}

validations=true

# Getting expected values
config=$(cat "$deployTestParametersFile")

# Count element on  C:\Users\Public\Desktop
countDesktopFilesPublic=$(plink -ssh -P 2204 $windowsAdminUsername@$(az vm show -d -g "$resourceGroup" -n ArcBox-Client --query publicIps -o tsv)   -pw "$windowsAdminSecret" -batch   'dir C:\Users\Public\Desktop /b | find /v /c "::"') || countDesktopFilesPublic=0
countDesktopFilesPublic=${countDesktopFilesPublic//[$'\t\r\n']}

# Count element on user Desktop
countDesktopFilesArcDemo=$(plink -ssh -P 2204 $windowsAdminUsername@$(az vm show -d -g "$resourceGroup" -n ArcBox-Client --query publicIps -o tsv)   -pw "$windowsAdminSecret" -batch   'dir c:\Users\'$windowsAdminUsername'\Desktop /b | find /v /c "::"') || countDesktopFilesArcDemo=0
countDesktopFilesArcDemo=${countDesktopFilesArcDemo//[$'\t\r\n']}

# Real Desktop elements
countDesktopFiles=$(( $countDesktopFilesPublic + $countDesktopFilesArcDemo))

# Get expected result
jqueryDesktopElementsExpected=".$flavor.desktopElementsExpected"
desktopElementsExpected=$(echo "$config" |  jq "$jqueryDesktopElementsExpected")

# Do the validation
if [ "$countDesktopFiles" -ge "$desktopElementsExpected" ]; then
  echo "Number of element on Desktop: $countDesktopFiles"
else
  echo "Unexpected number of element on Desktop: $countDesktopFiles"
  validations=false
fi

# fail if some validation was not reach
if [ "$validations" = "false" ]; then
   echo "Something was wrong. Failing"
   exit 1
fi
