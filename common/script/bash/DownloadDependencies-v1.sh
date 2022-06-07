#!/bin/bash

: "
.SYNOPSIS
  Download dependencies
.EXAMPLE
  globalDependencyArray=("InstallAzureCLIAndArcExtensions-v1" "InstallingRancherK3sSingleNode-v1")
  DownloadDependencies "${profileRootBaseUrl}" "${globalDependencyArray[@]}"
"

DownloadDependencies() {
  echo "Download dependencies"
  local profileRootBaseUrl=$1 # Save first argument in a variable
  echo "$profileRootBaseUrl"
  shift            # Shift all arguments to the left (original $1 gets lost)
  local dependencyArray=("$@") # Rebuild the array with rest of arguments
  for i in "${dependencyArray[@]}"; do
    local source="./$i.sh"
    echo "Downloading and installing: $source"
    sudo curl -o "$source" "${profileRootBaseUrl}common/script/bash/$i.sh"
    # shellcheck disable=SC1090
    source "$source"
  done
}
