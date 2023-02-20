# Define the GitHub repository and branch
$repository = "microsoft/azure_arc"
$branch = "main"

# Define the Azure API endpoint
$latest_api_url = "https://management.azure.com/providers?api-version=2022-01-01"

# Define the regular expressions to find the templates and resource types
$template_regex = "\.(json|bicep|tf|tf\.json)$"
$resource_type_regex = [regex]'"type"\s*:\s*"([^"]+)"\s*,\s*"apiVersion"\s*:\s*"([^"]+)"'

# Function to get the contents of a file in a GitHub repository
function Get-GitHubFileContent($repository, $branch, $path) {
    $url = "https://raw.githubusercontent.com/$repository/$branch/$path"
    return Invoke-RestMethod $url
}

# Function to compare two Azure API versions and return whether the first version is outdated
function Test-OutdatedApiVersion($current_api_version, $latest_api_version) {
    $current_api_version_int = [int]($current_api_version -replace "\D", "")
    $latest_api_version_int = [int]($latest_api_version -replace "\D", "")
    return $current_api_version_int -lt $latest_api_version_int
}

# Find all the ARM templates, bicep templates, and Terraform templates in the repository
$templates = (Invoke-RestMethod "https://api.github.com/repos/$repository/contents" -QueryParams @{ref=$branch}).where{ $_.type -eq "file" -and $_.name -match $template_regex }

# Loop through each template and find the resource types and API versions
$results = foreach ($template in $templates) {
    $path = $template.path
    $content = Get-GitHubFileContent -repository $repository -branch $branch -path $path
    $matches = $content | Select-String -AllMatches -Pattern $resource_type_regex
    foreach ($match in $matches) {
        $resource_type = $match.matches.groups[1].value
        $api_version = $match.matches.groups[2].value
        $latest_api_version = (Invoke-RestMethod $latest_api_url | Where-Object { $_.namespace -eq $resource_type }).apiVersions | Select-Object -Last 1
        if ($latest_api_version -and (Test-OutdatedApiVersion $api_version $latest_api_version)) {
            [pscustomobject]@{
                ResourceType = $resource_type
                OutdatedApiVersion = $api_version
                LatestApiVersion = $latest_api_version
                Path = $path
            }
        }
    }
}

# Write the results to a JSON file with a table
$results | ConvertTo-Json -Depth 100 | Out-File "report.json"
$table = $results | Select-Object ResourceType, OutdatedApiVersion, LatestApiVersion, Path | Format-Table -AutoSize | Out-String
[pscustomobject]@{
    Results = $results
    Table = $table
} | ConvertTo-Json -Depth 100 | Out-File "report-with-table.json"
