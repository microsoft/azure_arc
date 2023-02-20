[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$Repository,

    [Parameter(Mandatory=$false)]
    [string]$Branch = "main"
)

function Get-OutdatedApiVersion ($resourceType, $apiVersion) {
    $provider = Get-AzResourceProvider -ProviderNamespace $resourceType.Split('/')[0]
    $latestApiVersion = ($provider.ResourceTypes | Where-Object { $_.ResourceTypeName -eq $resourceType.Split('/')[1] }).ApiVersions[0]

    if ($apiVersion -ne $latestApiVersion) {
        [PSCustomObject]@{
            ResourceType = $resourceType
            OutdatedApiVersion = $apiVersion
            LatestApiVersion = $latestApiVersion
            FilePath = $file.Path
        }
    }
}

$files = Invoke-RestMethod "https://api.github.com/repos/$Repository/contents?ref=$Branch" -Headers @{
    "Accept" = "application/vnd.github.v3+json"
    "User-Agent" = "GitHub Actions"
}

$outdatedResources = foreach ($file in $files) {
    if ($file.Name -match "\.(json|bicep|tf)$") {
        $content = Invoke-RestMethod $file.Download_Url -Headers @{
            "Accept" = "application/vnd.github.v3.raw"
            "User-Agent" = "GitHub Actions"
        }

        if ($file.Name -like "*.json") {
            $template = ConvertFrom-Json $content
        }
        elseif ($file.Name -like "*.bicep") {
            $template = Invoke-Expression $content
        }
        elseif ($file.Name -like "*.tf") {
            $template = ConvertFrom-Json (ConvertTo-Json ((terraform show -json <<< $content) | ConvertFrom-Json))
        }

        foreach ($resource in $template.resources) {
            $resourceType = $resource.type
            $apiVersion = $resource.apiVersion

            if ($resourceType -match "^Microsoft\.(.*)\/(.*)$") {
                $outdatedApiVersion = Get-OutdatedApiVersion -resourceType $resourceType -apiVersion $apiVersion
                if ($outdatedApiVersion) {
                    $outdatedApiVersion
                }
            }
        }
    }
}

if ($outdatedResources) {
    $outdatedResources | Format-Table
    Write-Output "::set-output name=table::$(($outdatedResources | ConvertTo-Json))"
}
else {
    Write-Output "No outdated API versions found."
}
