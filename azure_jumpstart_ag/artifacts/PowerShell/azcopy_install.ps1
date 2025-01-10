$azCopyUrl = "https://aka.ms/downloadazcopy-v10-windows"
$downloadPath = "$env:TEMP\azcopy.zip"
$destinationFolder = "C:\Program Files\AzCopy"


# Download the AzCopy zip file
Write-Host "Downloading AzCopy from $azCopyUrl..."
Invoke-WebRequest -Uri $azCopyUrl -OutFile $downloadPath -ErrorAction Stop
Write-Host "Download completed."

# Create the destination folder if it doesn't exist
if (-not (Test-Path -Path $destinationFolder)) {
    Write-Host "Creating destination folder: $destinationFolder"
    New-Item -ItemType Directory -Path $destinationFolder -Force
}

# Extract the AzCopy zip file
Write-Host "Extracting AzCopy to $destinationFolder..."
Expand-Archive -Path $downloadPath -DestinationPath $destinationFolder -Force
Write-Host "Extraction completed."

# Move the contents of the azcopy subfolder one level up
$subfolder = Get-ChildItem -Path $destinationFolder -Directory | Where-Object { $_.Name -match "azcopy_windows_amd64" }
if ($subfolder) {
    Write-Host "Moving contents of $($subfolder.Name) one level up..."
    Move-Item -Path "$($subfolder.FullName)\*" -Destination $destinationFolder -Force
    Remove-Item -Path $subfolder.FullName -Recurse -Force
    Write-Host "Contents moved successfully."
} else {
    Write-Host "No subfolder matching 'azcopy_windows_amd64' found. Skipping move."
}

# Update the Path environment variable
Write-Host "Updating Path environment variable..."
$envPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
if (-not $envPath.Contains($destinationFolder)) {
    [Environment]::SetEnvironmentVariable("Path", "$envPath;$destinationFolder", [System.EnvironmentVariableTarget]::Machine)
    Write-Host "Path variable updated. Please restart PowerShell to reflect changes."
} else {
    Write-Host "Path already contains $destinationFolder. No changes made."
}

# Clean up
Write-Host "Cleaning up temporary files..."
Remove-Item -Path $downloadPath -Force
Write-Host "Temporary files cleaned up."

Write-Host "AzCopy installation and setup completed."