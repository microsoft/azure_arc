#!/bin/bash
ResourceGroup=${1}
Flavor=${2}
DeployTestParametersFile=${3}
deployBastion=${4}
vmUser=${5}
vmPassword=${6}

validations=true

config=$(cat "$DeployTestParametersFile")

countDesktopFilesPublic=$(plink -ssh -P 2204 $vmUser@$(az vm show -d -g "$ResourceGroup" -n ArcBox-Client --query publicIps -o tsv)   -pw "$vmPassword" -batch   'dir C:\Users\Public\Desktop /b | find /v /c "::"') || countDesktopFilesPublic=0
countDesktopFilesPublic=${countDesktopFilesPublic//[$'\t\r\n']}

countDesktopFilesArcDemo=$(plink -ssh -P 2204 $vmUser@$(az vm show -d -g "$ResourceGroup" -n ArcBox-Client --query publicIps -o tsv)   -pw "$vmPassword" -batch   'dir c:\Users\'$vmUser'\Desktop /b | find /v /c "::"') || countDesktopFilesArcDemo=0
countDesktopFilesArcDemo=${countDesktopFilesArcDemo//[$'\t\r\n']}

countDesktopFiles=$(( $countDesktopFilesPublic + $countDesktopFilesArcDemo))
jqueryDesktopElementsExpected=".$Flavor.desktopElementsExpected"
desktopElementsExpected=$(echo "$config" |  jq "$jqueryDesktopElementsExpected")
if [ "$countDesktopFiles" -ge "$desktopElementsExpected" ]; then
  echo "Number of element on Desktop: $countDesktopFiles"
else
  echo "Unexpected number of element on Desktop: $countDesktopFiles"
  validations=false
fi

if [ "$validations" = "false" ]; then
   echo "Something was wrong. Failing"
   exit 1
fi
