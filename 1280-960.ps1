## Must be executed with:
## powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\script.ps1"

param (
    [int]$newWidth = 1280,   # Default Width
    [int]$newHeight = 960   # Default Height
)

# Variables
$url = "https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/GameUserSettings.ini" 
$tempFilePath = "$env:TEMP\GameUserSettings.ini"
$cfgPath = "$env:LOCALAPPDATA\VALORANT\Saved\Config"

# Download cfg file
try {
    Invoke-WebRequest -Uri $url -OutFile $tempFilePath
    Write-Host "Downloaded file ok: $tempFilePath"
} catch {
    Write-Host "Something wrong."
    exit 1
}

# Get folders
$matchingFolders = Get-ChildItem -Path $cfgPath -Directory | Where-Object { $_.Name -match '^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}-ap$' }

if ($matchingFolders.Count -eq 0) {
    Write-Host "Open Valorant for config folder then rerun the script."
    exit 1
}

# Copy the file to the folders
foreach ($folder in $matchingFolders) {
    $windowsFolderPath = Join-Path $folder.FullName "Windows"
    $configFile = Join-Path $windowsFolderPath "GameUserSettings.ini"

    Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $false


    if (Test-Path $windowsFolderPath) {
        Copy-Item -Path $tempFilePath -Destination $windowsFolderPath -Force
        Write-Host "Done."
    } else {
        Write-Host "Config folder not found. Open Valorant first then rerun the script"
        exit 1
    }

    if (Test-Path $configFile) {  
        # Read the file
        $configContent = Get-Content $configFile

        # Replace the resolution settings
        $configContent = $configContent -replace 'ResolutionSizeX=\d+', "ResolutionSizeX=$newWidth"
        $configContent = $configContent -replace 'ResolutionSizeY=\d+', "ResolutionSizeY=$newHeight"

        $configContent = $configContent -replace 'LastUserConfirmedResolutionSizeX=\d+', "LastUserConfirmedResolutionSizeX=$newWidth"
        $configContent = $configContent -replace 'LastUserConfirmedResolutionSizeY=\d+', "LastUserConfirmedResolutionSizeY=$newHeight"

        # Save the modified file
        $configContent | Set-Content -Path $configFile -Encoding UTF8

        Write-Host "Current Res: ${newWidth} ${newHeight}"
    } 

    # Usually not required but still do to prevent Valorant from modifying the config
    Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $true
}
