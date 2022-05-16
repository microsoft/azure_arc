ExcludeRules=$1
RootFiles=$2

for file in $(find "$RootFiles" -iname "*.sh" -type f); do shellcheck --exclude="$ExcludeRules" "$file"; done
