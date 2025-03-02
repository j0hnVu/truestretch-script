# Define variables
$githubUrl = "https://raw.githubusercontent.com/your-repo/your-file.txt" 
$destinationFileName = "GameUserSettings.ini"  # Replace with actual filename
$tempFilePath = "$env:TEMP\$destinationFileName"
$valorantConfigPath = "$env:LOCALAPPDATA\VALORANT\Saved\Config"

# Download the file from GitHub
try {
    Invoke-WebRequest -Uri $githubUrl -OutFile $tempFilePath
    Write-Host "Downloaded file successfully: $tempFilePath"
} catch {
    Write-Host "Failed to download the file from GitHub."
    exit 1
}

# Get matching folder
$matchingFolders = Get-ChildItem -Path $valorantConfigPath -Directory | Where-Object { $_.Name -match '^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}-ap$' }

if ($matchingFolders.Count -eq 0) {
    Write-Host "No matching folder found."
    exit 1
}

# Copy the file to the matched folder(s)
foreach ($folder in $matchingFolders) {
    $windowsFolderPath = Join-Path $folder.FullName "Windows"
    if (Test-Path $windowsFolderPath) {
        Copy-Item -Path $tempFilePath -Destination $windowsFolderPath -Force
        Write-Host "Copied file to: $windowsFolderPath"
    } else {
        Write-Host "Skipping: No Windows folder found in $folder"
    }
}

Write-Host "Script execution completed."