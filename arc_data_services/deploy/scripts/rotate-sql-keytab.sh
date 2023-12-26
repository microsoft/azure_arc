#!/bin/bash -e

#
# Copyright (c) Microsoft Corporation. All rights reserved.
#
# This script updates a keytab file and a Kubernetes spec holding the keytab content.
#
# Prerequisites:
#
#  1) Install 'krb5-user' package:
#     $ sudo apt-get install krb5-user
#
#  2) The tool 'adutil' should be pre-installed if using --use-adutil flag.
#     Installation instructions: https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-ad-auth-adutil-introduction?view=sql-server-ver15&tabs=ubuntu
#
#  3) User must kinit with an AD user when using --use-adutil flag.
#

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -n|--sqlmi-name)
      sqlmi_name="$2"
      shift # past argument
      shift # past value
      ;;
    -s|--secret-name)
      secret_name="$2"
      shift # past argument
      shift # past value
      ;;
    -ns|--namespace)
      namespace="$2"
      shift # past argument
      shift # past value
      ;;
    -k|--keytab-file)
      keytab_file="$2"
      shift # past argument
      shift # past value
      ;;
    --use-adutil)
      use_adutil=yes
      shift # past argument
      ;;
    -h|--help)
      help=yes
      shift # past argument
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

if [ "$help" == "yes" ]; then
  echo ""
  echo "Required arguments:"
  echo "   --sqlmi-name -n          : Deployed SQL MI name to rotate keytab"
  echo "   --secret-name -s         : Keytab secret name to generate yaml template for"
  echo "   --namespace -ns          : SQL MI namespace"
  echo "   --keytab-file -k         : Keytab file name to generate"
  echo ""
  echo "Optional arguments:"
  echo "   --use-adutil             : Use adutil instead of ktutil (default)"
  echo "   --help -h                : Print help menu"
  echo ""
  echo "Optional environment variables:"
  echo "   AD_PASSWORD_CURRENT          : Current password for the Active Directory account pre-created for the SQL MI instance"
  echo "   AD_PASSWORD_NEW          : New password for the Active Directory account pre-created for the SQL MI instance"
  echo ""
  exit 0
fi

if [ -z "$sqlmi_name" ] || [ -z "$secret_name" ] || [ -z "$namespace" ]; then
  echo "Usage:"
  echo "  $0 --sqlmi-name <SQL MI name> --secret-name <keytab secret name> --namespace <SQL MI namespace>"
  echo "Example: "
  echo "  $0 --sqlmi-name arc-sqlmi --secret-name sqlmi-update-keytab-secret --namespace sqlmi-ns"
  exit 1
fi

# Get required keytab details from sqlmi spec i.e. realm, account, primary_dns_name, primary_port, secondary_dns_name, secondary_port
#
primary_dns_name=$(kubectl get sqlmi $sqlmi_name -n $namespace -o 'jsonpath={.spec.services.primary.dnsName}')
hostname=$(echo "$primary_dns_name" | awk -F'.' '{print $1}')
realm=${primary_dns_name:${#hostname}+1:${#primary_dns_name}} # Get the realm name by getting everything after the hostname. 
realm=${realm^^} # Convert realm to upper case
account=$(kubectl get sqlmi $sqlmi_name -n $namespace -o 'jsonpath={.spec.security.activeDirectory.accountName}')
primary_port=$(kubectl get sqlmi $sqlmi_name -n $namespace -o 'jsonpath={.spec.services.primary.port}')
secondary_dns_name=$(kubectl get sqlmi $sqlmi_name -n $namespace -o 'jsonpath={.spec.services.readableSecondaries.dnsName}')
secondary_port=$(kubectl get sqlmi $sqlmi_name -n $namespace -o 'jsonpath={.spec.services.readableSecondaries.port}')


echo ""
echo "Arguments:"
echo "  sqlmi-name          = $sqlmi_name"
echo "  secret-name         = $secret_name"
echo "  namespace           = $namespace"
echo "  keytab-file         = $keytab_file"
echo "Derived Values from spec:"
echo "  realm               = $realm"
echo "  account             = $account"
echo "  primary-dns-name    = $primary_dns_name"
echo "  primary-port        = $primary_port"
if [ ! -z "$secondary_dns_name" ]; then
  echo "  secondary-dns-name  = $secondary_dns_name"
fi
if [ ! -z "$secondary_port" ]; then
  echo "  secondary-port      = $secondary_port"
fi
echo ""

# Check keytab file
#
if [ -f "$keytab_file" ]; then
  echo "ERROR: Keytab file $keytab_file already exists."
  read -p "Should automatically delete the keytab file $keytab_file and proceed? (y/n): " yn
  case $yn in
    [Yy]* )
      rm $keytab_file
      echo "Keytab $keytab_file deleted. Proceeding..."
      ;;
    [Nn]* )
      exit
      ;;
    * )
      echo "Please answer y or n."
      exit
      ;;
  esac
  echo ""
fi

# Take old AD account password from user so that we can query the kvno
#
if [ -z "$AD_PASSWORD_CURRENT" ]; then
  echo -n AD Account \($account\) Current Password: 
  read -s AD_PASSWORD_CURRENT
  echo ""
  echo ""
fi

# Take new AD account password from user to generate new keytab entries with
#
if [ -z "$AD_PASSWORD_NEW" ]; then
  echo -n AD Account \($account\) New Password: 
  read -s AD_PASSWORD_NEW
  echo ""
  echo ""
fi

# Prepare SPN strings
#
spn_primary_dns=MSSQLSvc/$primary_dns_name
spn_primary_dns_port=MSSQLSvc/$primary_dns_name:$primary_port

if [ ! -z "$secondary_dns_name" ]; then
  spn_secondary_dns=MSSQLSvc/$secondary_dns_name
  if [ ! -z "$secondary_port" ]; then
    spn_secondary_dns_port=MSSQLSvc/$secondary_dns_name:$secondary_port
  fi
fi

# Function to get the kvno value for the associated account from the AD domain. This is done by exec'ing into the SQLMI pod and 
# getting a Kerberos TGT ticket using kinit with the given credentials.
#
sqlmi_pod=${sqlmi_name}"-0"
get_kvno_from_AD_domain()
{
  kubectl exec $sqlmi_pod -c arc-sqlmi -n $namespace -- bash -c echo "'$AD_PASSWORD_CURRENT' | kinit $account@$realm"
  kvnostring=$(kubectl exec $sqlmi_pod -c arc-sqlmi -n $namespace -- kvno $account@$realm)

  # Example output of kvno user@realm : 'user@realm: kvno = 5' Thus we need to extract the last integer from this string.
  # In order to do so, we need to split the string by the '=' delimeter, get the last element of the resulting array and trim it.
  # We can do this by setting the IFS='='. 
  #
  # Copy the old value of $IFS so that we can restore it once we are done with our operation
  #
  OIFS=$IFS

  # Split kvnosting by ' ' and copy the resulting array is fields
  #
  IFS='=' read -ra fields <<< "$kvnostring"

  # The last element of fields is the kvno number
  #
  kvno=${fields[-1]}

  # Restore the old value of IFS
  #
  IFS=$OIFS

  echo $kvno
}

# Get kvno from AD Domain
#
kvno=$(get_kvno_from_AD_domain)

# Increment kvno by 1. The arithmetic operation takes care of the leading whitespace on the kvno.
#
new_kvno=$((kvno+1))

# Function to create keytab using adutil. The first parameter passed to this is the kvno number.
#
create_keytab_with_adutil()
{
  adutil keytab create --path $keytab_file --principal $account@$realm  --enctype aes256-cts-hmac-sha1-96,arcfour-hmac --password $2 --kvno $1
  echo "Keytab entries added for: $account@$realm"

  adutil keytab create --path $keytab_file --principal $spn_primary_dns@$realm  --enctype aes256-cts-hmac-sha1-96,arcfour-hmac --password $2 --kvno $1
  echo "Keytab entries added for: $spn_primary_dns@$realm"

  adutil keytab create --path $keytab_file --principal $spn_primary_dns_port@$realm  --enctype aes256-cts-hmac-sha1-96,arcfour-hmac --password $2 --kvno $1
  echo "Keytab entries added for: $spn_primary_dns_port@$realm"

  if [ ! -z "$spn_secondary_dns" ]; then
    adutil keytab create --path $keytab_file --principal $spn_secondary_dns@$realm  --enctype aes256-cts-hmac-sha1-96,arcfour-hmac --password $2 --kvno $1
    echo "Keytab entries added for: $spn_secondary_dns@$realm"
  fi

  if [ ! -z "$spn_secondary_dns_port" ]; then
    adutil keytab create --path $keytab_file --principal $spn_secondary_dns_port@$realm  --enctype aes256-cts-hmac-sha1-96,arcfour-hmac --password $2 --kvno $1
    echo "Keytab entries added for: $spn_secondary_dns_port@$realm"
  fi
}

# Function to create keytab using ktutil. The first parameter passed to this is the kvno number.
#
create_keytab_with_ktutil()
{
  printf "%b" "addent -password -p $account@$realm -k $1 -e aes256-cts-hmac-sha1-96\n$2\nwrite_kt $keytab_file" | ktutil
  printf "%b" "addent -password -p $account@$realm -k $1 -e arcfour-hmac\n$2\nwrite_kt $keytab_file" | ktutil
  echo "Keytab entries added for: $account@$realm"

  printf "%b" "addent -password -p $spn_primary_dns@$realm -k $1 -e aes256-cts-hmac-sha1-96\n$2\nwrite_kt $keytab_file" | ktutil
  printf "%b" "addent -password -p $spn_primary_dns@$realm -k $1 -e arcfour-hmac\n$2\nwrite_kt $keytab_file" | ktutil
  echo "Keytab entries added for: $spn_primary_dns@$realm"

  printf "%b" "addent -password -p $spn_primary_dns_port@$realm -k $1 -e aes256-cts-hmac-sha1-96\n$2\nwrite_kt $keytab_file" | ktutil
  printf "%b" "addent -password -p $spn_primary_dns_port@$realm -k $1 -e arcfour-hmac\n$2\nwrite_kt $keytab_file" | ktutil
  echo "Keytab entries added for: $spn_primary_dns_port@$realm"

  if [ ! -z "$spn_secondary_dns" ]; then
    printf "%b" "addent -password -p $spn_secondary_dns@$realm -k $1 -e aes256-cts-hmac-sha1-96\n$2\nwrite_kt $keytab_file" | ktutil
    printf "%b" "addent -password -p $spn_secondary_dns@$realm -k $1 -e arcfour-hmac\n$2\nwrite_kt $keytab_file" | ktutil
    echo "Keytab entries added for: $spn_secondary_dns@$realm"
  fi

  if [ ! -z "$spn_secondary_dns_port" ]; then
    printf "%b" "addent -password -p $spn_secondary_dns_port@$realm -k $1 -e aes256-cts-hmac-sha1-96\n$2\nwrite_kt $keytab_file" | ktutil
    printf "%b" "addent -password -p $spn_secondary_dns_port@$realm -k $1 -e arcfour-hmac\n$2\nwrite_kt $keytab_file" | ktutil
    echo "Keytab entries added for: $spn_secondary_dns_port@$realm"
  fi
}

# Create new keytab file with entries for current crendentials (current kvno) and new credentials (new kvno)
#
if [ "$use_adutil" == "yes" ]; then
  echo "Using adutil for keytab generation..."

  # Add entries for current password first
  create_keytab_with_adutil $kvno $AD_PASSWORD_CURRENT

  # Add entries for new password
  create_keytab_with_adutil $new_kvno $AD_PASSWORD_NEW

else
  echo "Using ktutil for keytab generation..."

  # Add entries for current password first
  create_keytab_with_ktutil $kvno $AD_PASSWORD_CURRENT

  # Add entries for new password
  create_keytab_with_ktutil $new_kvno $AD_PASSWORD_NEW
fi

echo ""
echo "Keytab generated:"
klist -kte $keytab_file
echo ""

# Generate keytab secret yaml
#
base64_keytab=$(base64 -i $keytab_file | tr -d '\n')

# Use the same directory as keytab to write the file in.
#
directory=$(dirname $keytab_file)
secret_file=$directory/$secret_name.yaml

cat <<EOF > $secret_file
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: $secret_name
  namespace: $namespace
data:
  keytab:
    $base64_keytab
EOF

echo "Generated $secret_file:"
echo ""
cat $secret_file
echo ""

echo "Applying secret $secret_name to namespace $namespace"
echo ""

# Apply secret to the given namespace
#
kubectl apply -f $secret_file -n $namespace

# Edit SQL MI spec to point to the new secret
#
kubectl patch sqlmi $sqlmi_name -n $namespace --type='json' -p='[{"op": "replace", "path": "/spec/security/activeDirectory/keytabSecret", "value":"'${secret_name}'"}]'

# Wait until SQL MI is in ready state
retry_pause=15
sleep $retry_pause
sqlmi_state=$(kubectl get sqlmi $sqlmi_name -o jsonpath='{.status.state}' -n $namespace)
tries=0
while [[ "$sqlmi_state" != "Ready" && $tries -lt 40 ]]; do
  echo "'$sqlmi_name' has state '$sqlmi_state' which is not Ready. Retrying in $retry_pause seconds..."
  sleep $retry_pause
  sqlmi_state=$(kubectl get sqlmi $sqlmi_name -o jsonpath='{.status.state}' -n $namespace)
  tries=$((tries+1))
done

# If we have exhausted retry attempts while waiting for SQL MI to be in ready state, print command used to check the state before exiting
#
if [[ "$sqlmi_state" != "Ready" ]]; then
  echo "Exhausted retry attempts while waiting for SQL MI '$sqlmi_name' to get to Ready state"
  echo "Please check SQL MI state by running the following command:"
  echo "kubectl get sqlmi $sqlmi_name -o jsonpath='{.status.state}' -n $namespace"
else
  if kubectl exec $sqlmi_pod -c arc-sqlmi -n $namespace -- bash -c echo "'$AD_PASSWORD_CURRENT' | kinit $account@$realm" ; then
    echo "AD keytab successfully rotated for SQL MI '$sqlmi_name'"
  else
    echo "Rotation failed for AD keytab for SQL MI '$sqlmi_name'"
    echo "Could not kinit using the current credentials for '$account@$realm'"
    echo "Please check the troubleshooting guide to troubleshoot the error"
  fi
fi