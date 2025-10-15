param (
    [int]$newWidth = 1280,   # Default Width
    [int]$newHeight = 960,  # Default Height
    [string]$region = "ap" # Default region
)


Write-Host "

         / \
        |\_/|
        |---|
        |   |
        |   |
      _ |=-=| _
  _  / \|   |/ \
 / \|   |   |   ||\
|   |   |   |   | \>
|   |   |   |   |   \
| -   -   -   - |)   )
|                   /
 \                 /
  \               /
   \             /
    \           /

"

Clear-Host
Write-Host "              
              .-------------------------------.
             /                               /|
            /                               / |
           /                               /  |
          /                               /   |
         .-------------------------------.    |
         |`-------------------------------`|  |
         | |                             | |  |
         | |                             | |  |
         | |                             | |  |
         | |     H A V D E P T R A I     | |  |
         | |                             | |  |
         | |                             | |  /
         | |_____________________________| | /
         |_________________________________|/
          `-----------. .-----------`
        /:::::::::::::::V:::::::::::::::
       /---------------------------------
      `---------------------------------`
       /`-----------------------------`
      /              ...              /
     /_______________________________/
"

Start-Sleep 1
Clear-Host

Write-Host "              
              .-------------------------------.
             /                               /|
            /                               / |
           /                               /  |
          /                               /   |
         .-------------------------------.    |
         |`-------------------------------`|  |
         | |                             | |  |
         | |                             | |  |
         | |                             | |  |
         | |       DIT ME MINH TO        | |  |
         | |                             | |  |
         | |                             | |  /
         | |_____________________________| | /
         |_________________________________|/
          `-----------. .-----------`
        /:::::::::::::::V:::::::::::::::
       /---------------------------------
      `---------------------------------`
       /`-----------------------------`
      /              ...              /
     /_______________________________/
"
Start-Sleep 1

# Variables
$configUrl = "https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/GameUserSettings.ini"

$region = "-$region" # Temporary hardcoded region

$cfgPath = "$env:LOCALAPPDATA\VALORANT\Saved\Config"
$tmpCfgFilePath = "$env:TEMP\GameUserSettings.ini"
$altPath = "SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration"
$fullPath = "Registry::HKEY_LOCAL_MACHINE\$altPath"

Clear-Host


# Resource Check
$isConfigDownload = $false

function takeRegOwnership {
    param (
        [string]$Path
        )
    # Open the registry key with permissions to take ownership
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
        $Path,
        [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
        [System.Security.AccessControl.RegistryRights]::TakeOwnership
    )
    # Get the current ACL for the registry key
    $acl = $key.GetAccessControl()
    # Set the new owner
    $acl.SetOwner([System.Security.Principal.NTAccount] "BUILTIN\Administrators")
    # Apply the updated ACL to the registry key
    $key.SetAccessControl($acl)
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
        Clear-Host
        Write-Host "Riot Client is not running."
        Start-Sleep 1
    }
}

# Retrive PUUID using Riot Client Local API to create folder
while (-not $getResponse){
    if ($retryCount -lt 50){
        # Using Riot Client Local API to get PUUID
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
                Clear-Host
                Write-Host "Attempt $($retryCount + 1): Please login. Retry after 5 seconds."
                $retryCount++
                Start-Sleep 5
            } else {
                Write-Host "Error: $(($_ | ConvertFrom-Json).message)"
                $retryCount++
                Start-Sleep 2
            }
        }
    } else {
    # Quit the script if no PUUID is retrived.
    Write-Host "Failed to get PUUID after 5 attempts"
    exit 1
    }
}

$puuidFolder = "$puuid$region"
$windowsClientFolder = Join-Path $cfgPath "WindowsClient"
$userWindowsClientFolder = Join-Path "$cfgPath" "$puuidFolder\WindowsClient"
$configFile = Join-Path "$windowsClientFolder" "GameUserSettings.ini"
$userConfigFile = Join-Path "$userWindowsClientFolder" "GameUserSettings.ini"

# Create folder with PUUID of the account if not exist
if (-not (Test-Path $userWindowsClientFolder)) {
    New-Item -Path "$userWindowsClientFolder" -ItemType Directory -Force
    }

if (-not (Test-Path $windowsClientFolder)) {
    New-Item -Path "$windowsClientFolder" -ItemType Directory -Force
    }

# Copy the base GameUserSettings.ini file 
Copy-Item -Path $tmpCfgFilePath -Destination $userWindowsClientFolder -Force
Copy-Item -Path $tmpCfgFilePath -Destination $windowsClientFolder -Force
Write-Host "Done."

# Disable ReadOnly
Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $false
Set-ItemProperty -Path $userConfigFile -Name IsReadOnly -Value $false

# If the config file exists, and the width & height isn't the default value, change the value in the config file
if (
    (Test-Path $configFile) -and 
    (Test-Path $userConfigFile) -and 
    (
        ($newWidth -ne 1280) -or 
        ($newHeight -ne 960)
    )
) {  
    # Read the file
    $configContent = Get-Content $configFile

    # Replace the resolution settings
    $configContent = $configContent -replace 'ResolutionSizeX=\d+', "ResolutionSizeX=$newWidth"
    $configContent = $configContent -replace 'ResolutionSizeY=\d+', "ResolutionSizeY=$newHeight"

    $configContent = $configContent -replace 'LastUserConfirmedResolutionSizeX=\d+', "LastUserConfirmedResolutionSizeX=$newWidth"
    $configContent = $configContent -replace 'LastUserConfirmedResolutionSizeY=\d+', "LastUserConfirmedResolutionSizeY=$newHeight"

    # Save the modified file
    $configContent | Set-Content -Path $configFile -Encoding UTF8
    $configContent | Set-Content -Path $userConfigFile -Encoding UTF8

    Write-Host "Config Res: ${newWidth} ${newHeight}"
} 

# Reenable ReadOnly. Usually not required but still do to prevent Valorant from modifying the config
Set-ItemProperty -Path $configFile -Name IsReadOnly -Value $true
Set-ItemProperty -Path $userConfigFile -Name IsReadOnly -Value $true