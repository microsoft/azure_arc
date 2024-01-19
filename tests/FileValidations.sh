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
countDesktopFilesPublic=$(plink -ssh -P 2204 $windowsAdminUsername@$(az vm show -d -g "$resourceGroup" -n ArcBox-Client --query publicIps -o tsv) -pw "$windowsAdminSecret" -batch 'dir C:\Users\Public\Desktop /b | find /v /c "::"') || countDesktopFilesPublic=0
countDesktopFilesPublic=${countDesktopFilesPublic//[$'\t\r\n']/}

# Count element on user Desktop
countDesktopFilesArcDemo=$(plink -ssh -P 2204 $windowsAdminUsername@$(az vm show -d -g "$resourceGroup" -n ArcBox-Client --query publicIps -o tsv) -pw "$windowsAdminSecret" -batch 'dir c:\Users\'$windowsAdminUsername'\Desktop /b | find /v /c "::"') || countDesktopFilesArcDemo=0
countDesktopFilesArcDemo=${countDesktopFilesArcDemo//[$'\t\r\n']/}

# Real Desktop elements
countDesktopFiles=$(($countDesktopFilesPublic + $countDesktopFilesArcDemo))

# Get expected result
jqueryDesktopElementsExpected=".$flavor.desktopElementsExpected"
desktopElementsExpected=$(echo "$config" | jq "$jqueryDesktopElementsExpected")

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
azuredatastudioSettingExpected=$(echo "$config" | jq "$jqueryAzuredatastudioSettingExpected")

if [ $azuredatastudioSettingExpected -gt 0 ]; then
  countAzuredatastudioSetting=$(plink -ssh -P 2204 $windowsAdminUsername@$(az vm show -d -g "$resourceGroup" -n ArcBox-Client --query publicIps -o tsv) -pw "$windowsAdminSecret" -batch 'dir C:\Users\'$windowsAdminUsername'\AppData\Roaming\azuredatastudio\User\settings.json /b | find /v /c "::"') || countAzuredatastudioSetting=0
  countAzuredatastudioSetting=${countAzuredatastudioSetting//[$'\t\r\n']/}

  countAzuredatastudioSettingSize=$(plink -ssh -P 2204 $windowsAdminUsername@$(az vm show -d -g "$resourceGroup" -n ArcBox-Client --query publicIps -o tsv) -pw "$windowsAdminSecret" -batch 'forfiles /p C:\Users\'$windowsAdminUsername'\AppData\Roaming\azuredatastudio\User /m settings.json /c "cmd /c echo @fsize"')
  countAzuredatastudioSettingSize=${countAzuredatastudioSettingSize//[$'\t\r\n']/}

  if [ $countAzuredatastudioSetting -gt 0 ]; then
    if [ $countAzuredatastudioSettingSize -gt 0 ]; then
      echo "Azuredatastudio Setting exists and size is bigger than 1"
      azuredatastudioSetting=$(plink -ssh -P 2204 $windowsAdminUsername@$(az vm show -d -g "$resourceGroup" -n ArcBox-Client --query publicIps -o tsv) -pw "$windowsAdminSecret" -batch 'type C:\Users\'$windowsAdminUsername'\AppData\Roaming\azuredatastudio\User\settings.json')
      connections=$(echo $azuredatastudioSetting | jq '."datasource.connections" | length')
      if [ $connections = "2" ]; then
        echo "We detected two connection on azure data studio setting. it is expected"
        for index in 0 1; do
          jqQuery='."datasource.connections"['$index'].options.connectionName'
          connectionName=$(echo $azuredatastudioSetting | jq -r $jqQuery)
          if [ $connectionName == "ArcSQLMI" ]; then
            jqQuery='."datasource.connections"['$index'].options.server'
            server=$(echo $azuredatastudioSetting | jq -r $jqQuery)
            arrServer=(${server//,/ })
            port=${arrServer[1]}
            if [ -z "$port" ] || [ $port == "null" ]; then
              echo "Azure data studio setting: ArcSQLMI port is null"
              validations=false
            else
              re='^[0-9]+$'
              if ! [[ $port =~ $re ]]; then
                echo "Azure data studio setting: ArcSQLMI port is Not a Number"
                validations=false
              else
                echo "Azure data studio setting: ArcSQLMI port has value and it is a number"
              fi
            fi
          fi
          if [ $connectionName == "ArcPostgres" ]; then
            jqQuery='."datasource.connections"['$index'].options.port'
            port=$(echo $azuredatastudioSetting | jq -r $jqQuery)
            if [ -z "$port" ] || [ $port == "null" ]; then
              echo "Azure data studio setting: ArcPostgres port is null"
              validations=false
            else
              re='^[0-9]+$'
              if ! [[ $port =~ $re ]]; then
                echo "Azure data studio setting: ArcPostgres port is Not a Number"
                validations=false
              else
                echo "Azure data studio setting: ArcPostgres port has value and it is a number"
              fi
            fi
          fi
        done
      else
        echo "Two connections are expected on azure data studio setting and we found $connections"
      fi
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
