#!/bin/bash -e

#
# Copyright (c) Microsoft Corporation. All rights reserved.
#
# This script creates a keytab file and a Kubernetes spec holding the keytab content.
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
    -r|--realm)
      realm="$2"
      shift # past argument
      shift # past value
      ;;
    -a|--account)
      account="$2"
      shift # past argument
      shift # past value
      ;;
    -d|--dns-name)
      dns_name="$2"
      shift # past argument
      shift # past value
      ;;
    -p|--port)
      port="$2"
      shift # past argument
      shift # past value
      ;;
    -sd|--secondary-dns-name)
      secondary_dns_name="$2"
      shift # past argument
      shift # past value
      ;;
    -sp|--secondary-port)
      secondary_port="$2"
      shift # past argument
      shift # past value
      ;;
    -k|--keytab-file)
      keytab_file="$2"
      shift # past argument
      shift # past value
      ;;
    -s|--secret-name)
      secret_name="$2"
      shift # past argument
      shift # past value
      ;;
    -ns|--secret-namespace)
      secret_namespace="$2"
      shift # past argument
      shift # past value
      ;;
    --kvno)
      kvno="$2"
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
  echo "   --realm -r               : Active Directory domain name or Kerberos realm (upper case)"
  echo "   --account -a             : Active Directory account name pre-created for the SQL MI instance"
  echo "   --dns-name -d            : Fully-qualified DNS name for the primary SQL endpoint"
  echo "   --port -p                : External port number for the primary SQL endpoint"
  echo "   --keytab-file -k         : Keytab file name to generate"
  echo "   --secret-name -s         : Keytab secret name to generate yaml template for"
  echo "   --secret-namespace -ns   : Keytab secret namespace"
  echo ""
  echo "Optional arguments:"
  echo "   --kvno                   : msDS-KeyVersionNumber of the AD account (default is 2)"
  echo "   --use-adutil             : Use adutil instead of ktutil (default)"
  echo "   --secondary-dns-name -sd : Fully-qualified DNS name for the secondary SQL endpoint"
  echo "   --secondary-port -sp     : External port number for the secondary SQL endpoint"
  echo "   --help -h                : Print help menu"
  echo ""
  echo "Optional environment variables:"
  echo "   AD_PASSWORD              : Password for the Active Directory account pre-created for the SQL MI instance"
  echo ""
  exit 0
fi

if [ -z "$realm" ] || [ -z "$account" ] || [ -z "$dns_name" ] || [ -z "$port" ] || [ -z "$keytab_file" ] || [ -z "$secret_name" ] || [ -z "$secret_namespace" ]; then
  echo "Usage:"
  echo "  $0 --realm <realm>   --account <AD account>   --dns-name <endpoint DNS name> --port <endpoint port number> --keytab-file <keytab file name> --secret-name <keytab secret name> --secret-namespace <keytab secret namespace>"
  echo "Example: "
  echo "  $0 --realm ARC.LOCAL --account sqlmi1-account --dns-name sqlmi1.arc.local    --port 31433                  --keytab-file mssql.keytab       --secret-name sqlmi1-keytab-secret --secret-namespace test"
  exit 1
fi

echo ""
echo "Arguments:"
echo "  realm               = $realm"
echo "  account             = $account"
echo "  dns_name            = $dns_name"
echo "  port                = $port"
if [ ! -z "$secondary_dns_name" ]; then
  echo "  secondary_dns_name  = $secondary_dns_name"
fi
if [ ! -z "$secondary_port" ]; then
  echo "  secondary_port      = $secondary_port"
fi
echo "  keytab_file         = $keytab_file"
echo "  secret_name         = $secret_name"
echo "  secret_namespace    = $secret_namespace"
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

# Take AD account password from user
#
if [ -z "$AD_PASSWORD" ]; then
  echo -n AD Account \($account\) Password: 
  read -s AD_PASSWORD
  echo ""
  echo ""
fi

# Prepare SPN strings
#
spn_primary_dns=MSSQLSvc/$dns_name
spn_primary_dns_port=MSSQLSvc/$dns_name:$port

if [ ! -z "$secondary_dns_name" ]; then
  spn_secondary_dns=MSSQLSvc/$secondary_dns_name
  if [ ! -z "$secondary_port" ]; then
    spn_secondary_dns_port=MSSQLSvc/$secondary_dns_name:$secondary_port
  fi
fi

# Set kvno to 2 (default until password change).
#
if [ -z "$kvno" ]; then
  kvno=2
fi

# Generate keytab file.
#
if [ "$use_adutil" == "yes" ]; then
  echo "Using adutil for keytab generation..."

  adutil keytab create --path $keytab_file --principal $account@$realm  --enctype aes256-cts-hmac-sha1-96,arcfour-hmac --password $AD_PASSWORD --kvno $kvno
  echo "Keytab entries added for: $account@$realm"

  adutil keytab create --path $keytab_file --principal $spn_primary_dns@$realm  --enctype aes256-cts-hmac-sha1-96,arcfour-hmac --password $AD_PASSWORD --kvno $kvno
  echo "Keytab entries added for: $spn_primary_dns@$realm"

  adutil keytab create --path $keytab_file --principal $spn_primary_dns_port@$realm  --enctype aes256-cts-hmac-sha1-96,arcfour-hmac --password $AD_PASSWORD --kvno $kvno
  echo "Keytab entries added for: $spn_primary_dns_port@$realm"

  if [ ! -z "$spn_secondary_dns" ]; then
    adutil keytab create --path $keytab_file --principal $spn_secondary_dns@$realm  --enctype aes256-cts-hmac-sha1-96,arcfour-hmac --password $AD_PASSWORD --kvno $kvno
    echo "Keytab entries added for: $spn_secondary_dns@$realm"
  fi

  if [ ! -z "$spn_secondary_dns_port" ]; then
    adutil keytab create --path $keytab_file --principal $spn_secondary_dns_port@$realm  --enctype aes256-cts-hmac-sha1-96,arcfour-hmac --password $AD_PASSWORD --kvno $kvno
    echo "Keytab entries added for: $spn_secondary_dns_port@$realm"
  fi

else
  echo "Using ktutil for keytab generation..."

  printf "%b" "addent -password -p $account@$realm -k $kvno -e aes256-cts-hmac-sha1-96\n$AD_PASSWORD\nwrite_kt $keytab_file" | ktutil
  printf "%b" "addent -password -p $account@$realm -k $kvno -e arcfour-hmac\n$AD_PASSWORD\nwrite_kt $keytab_file" | ktutil
  echo "Keytab entries added for: $account@$realm"

  printf "%b" "addent -password -p $spn_primary_dns@$realm -k $kvno -e aes256-cts-hmac-sha1-96\n$AD_PASSWORD\nwrite_kt $keytab_file" | ktutil
  printf "%b" "addent -password -p $spn_primary_dns@$realm -k $kvno -e arcfour-hmac\n$AD_PASSWORD\nwrite_kt $keytab_file" | ktutil
  echo "Keytab entries added for: $spn_primary_dns@$realm"

  printf "%b" "addent -password -p $spn_primary_dns_port@$realm -k $kvno -e aes256-cts-hmac-sha1-96\n$AD_PASSWORD\nwrite_kt $keytab_file" | ktutil
  printf "%b" "addent -password -p $spn_primary_dns_port@$realm -k $kvno -e arcfour-hmac\n$AD_PASSWORD\nwrite_kt $keytab_file" | ktutil
  echo "Keytab entries added for: $spn_primary_dns_port@$realm"

  if [ ! -z "$spn_secondary_dns" ]; then
    printf "%b" "addent -password -p $spn_secondary_dns@$realm -k $kvno -e aes256-cts-hmac-sha1-96\n$AD_PASSWORD\nwrite_kt $keytab_file" | ktutil
    printf "%b" "addent -password -p $spn_secondary_dns@$realm -k $kvno -e arcfour-hmac\n$AD_PASSWORD\nwrite_kt $keytab_file" | ktutil
    echo "Keytab entries added for: $spn_secondary_dns@$realm"
  fi

  if [ ! -z "$spn_secondary_dns_port" ]; then
    printf "%b" "addent -password -p $spn_secondary_dns_port@$realm -k $kvno -e aes256-cts-hmac-sha1-96\n$AD_PASSWORD\nwrite_kt $keytab_file" | ktutil
    printf "%b" "addent -password -p $spn_secondary_dns_port@$realm -k $kvno -e arcfour-hmac\n$AD_PASSWORD\nwrite_kt $keytab_file" | ktutil
    echo "Keytab entries added for: $spn_secondary_dns_port@$realm"
  fi
fi

echo ""
echo "Keytab generated:"
klist -kte $keytab_file
echo ""

# Generating keytab secret yaml
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
  namespace: $secret_namespace
data:
  keytab:
    $base64_keytab
EOF

echo "Generated $secret_file:"
echo ""
cat $secret_file
echo ""
echo "Done!"
echo ""
