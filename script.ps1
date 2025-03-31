param (
    [int]$newWidth = 1280,   # Default Width
    [int]$newHeight = 960   # Default Height
    )

# Variables
$url = "https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/GameUserSettings.ini" 
$tempFilePath = "$env:TEMP\GameUserSettings.ini"
$cfgPath = "$env:LOCALAPPDATA\VALORANT\Saved\Config"
$region = "-ap" # Temporary hardcoded region

clear

# Download cfg file
try {
    Invoke-WebRequest -Uri $url -OutFile $tempFilePath
    Write-Host "Base file downloaded ok: $tempFilePath"
} catch {
        Write-Host "Something wrong. Internet Connection or something."
        exit 1
    }

# Powershell version < 7.4 doesn't use the -SkipCertificateCheck
Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$getResponse = $false
$isRiotClient = $false
$retryCount = 0

# Check for Riot Client Process
while (-not $isRiotClient){
    if (Get-Process -Name "Riot Client" -ErrorAction SilentlyContinue) {
        Write-Host "Riot Client is running. Continue."
        $isRiotClient = $true
        Write-Host "`n"
    } else {
        Write-Host "Riot Client is not running."
        Start-Sleep 1
    }
}

# Retrive PUUID using LCU API to create folder
while (-not $getResponse){
    # Using LCU API to get PUUID
    $port = Get-Content "$env:LOCALAPPDATA\Riot Games\Riot Client\Config\lockfile" | ForEach-Object { ($_ -split ':')[2] }
    $token = Get-Content "$env:LOCALAPPDATA\Riot Games\Riot Client\Config\lockfile" | ForEach-Object { ($_ -split ':')[3] }
    $headers = @{
    Authorization = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("riot:$token")))"
    "Content-Type" = "application/json"
}

    try {
        $puuid = Invoke-RestMethod -Uri "https://127.0.0.1:$port/riot-messaging-service/v1/user" -Headers $headers

        $nametag = Invoke-RestMethod -Uri "https://127.0.0.1:$port/player-account/aliases/v1/display-name" -Headers $headers

        Write-Host "Logged in as: $($nametag.gameName)#$($nametag.tagLine)"

        if ($puuid -Match '^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$'){
            Write-Host "Valid PUUID. Continue."
            $getResponse = $true
        }
    } catch {
        if ($(($_ | ConvertFrom-Json).message) -eq "User is not authenticated"){
            Write-Host "Attempt $($retryCount + 1): Please login. Retry after 5 seconds."
            $retryCount++
            Start-Sleep 5
        } else {
            Write-Host "Error: $(($_ | ConvertFrom-Json).message)"
            $retryCount++
            Start-Sleep 2
        }
    }
}


# Quit the script if no PUUID is retrived.
if (-not $getResponse) {
    Write-Host "Failed to get PUUID after 5 attempts"
    exit 1
}

$puuidFolder = "$puuid$region"
$windowsFolderPath = Join-Path "$cfgPath" "$puuidFolder\Windows"
$configFile = Join-Path "$windowsFolderPath" "GameUserSettings.ini"

# Create folder with PUUID of the account if not exist
if (-not (Test-Path $windowsFolderPath)) {
    New-Item -Path "$windowsFolderPath" -ItemType Directory -Force
    }

# Copy the base GameUserSettings.ini file 
Copy-Item -Path $tempFilePath -Destination $windowsFolderPath -Force
Write-Host "Done."

# Disable ReadOnly
Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $false

# If the config file exists, and the width & height isn't the default value, change the value in the config file
if ((Test-Path $configFile) -and (($newWidth -ne 1280) -and ($newHeight -ne 960))) {  
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

# Reenable ReadOnly. Usually not required but still do to prevent Valorant from modifying the config
Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $true