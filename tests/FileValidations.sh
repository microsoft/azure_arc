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

# validate Azuredatastudio Setting 

# Get expected result
jqueryAzuredatastudioSettingExpected=".$flavor.azuredatastudioSettingExpected"
azuredatastudioSettingExpected=$(echo "$config" |  jq "$jqueryAzuredatastudioSettingExpected")

if [ $azuredatastudioSettingExpected -gt 0 ]; then
  countAzuredatastudioSetting=$(plink -ssh -P 2204 $windowsAdminUsername@$(az vm show -d -g "$resourceGroup" -n ArcBox-Client --query publicIps -o tsv)   -pw "$windowsAdminSecret" -batch   'dir C:\Users\'$windowsAdminUsername'\AppData\Roaming\azuredatastudio\User\settings.json /b | find /v /c "::"') || countAzuredatastudioSetting=0
  countAzuredatastudioSetting=${countAzuredatastudioSetting//[$'\t\r\n']}

  countAzuredatastudioSettingSize=$(plink -ssh -P 2204 $windowsAdminUsername@$(az vm show -d -g "$resourceGroup" -n ArcBox-Client --query publicIps -o tsv)   -pw "$windowsAdminSecret" -batch  'forfiles /p C:\Users\'$windowsAdminUsername'\AppData\Roaming\azuredatastudio\User /m settings.json /c "cmd /c echo @fsize"')
  countAzuredatastudioSettingSize=${countAzuredatastudioSettingSize//[$'\t\r\n']}

  if [ $countAzuredatastudioSetting -gt 0 ]; then
    if [ $countAzuredatastudioSettingSize -gt 0 ]; then
      echo "Azuredatastudio Setting exists and size is bigger than 1, see the downloaded file later on"
    else
       echo "Unexpected size of element on AzuredatastudioSetting: $countAzuredatastudioSettingSize"
    fi
  else
    echo "Unexpected number of element on AzuredatastudioSetting: $countAzuredatastudioSetting"
    validations=false
  fi
fi

# fail if some validation was not reach
if [ "$validations" = "false" ]; then
   echo "Something was wrong. Failing"
   exit 1
fi
