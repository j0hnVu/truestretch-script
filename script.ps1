param (
    [int]$newWidth = 1280,   # Default Width
    [int]$newHeight = 960   # Default Height
    )

# Variables
$configUrl = "https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/GameUserSettings.ini"
$qresUrl = "https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/tools/QRes.exe"
$cruUrl = "https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/tools/restart-only.exe"
$tempFilePath = "$env:TEMP\GameUserSettings.ini"
$cfgPath = "$env:LOCALAPPDATA\VALORANT\Saved\Config"
$region = "-ap" # Temporary hardcoded region

$altPath = "SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Configuration"
$fullPath = "Registry::HKEY_LOCAL_MACHINE\$altPath"

clear

# Download necessary file
$isConfigDownload = $false
$isQresDownload = $false
$isCruDownload = $false
try {
    Invoke-WebRequest -Uri $configUrl -OutFile $tempFilePath # Base config file
    $isConfigDownload = $true
    Write-Host "Base file downloaded ok: $tempFilePath"
} catch {
        Write-Host "Something wrong. Internet Connection or something."
        exit 1
}

try {
    Invoke-WebRequest -Uri $cruUrl -OutFile "./restart-only.exe"
    $isCruDownload = $true
    Write-Host "restart-only.exe downloaded ok."
} catch {
        Write-Host "Something wrong. restart-only.exe is not downloaded"
}

try {
    Invoke-WebRequest -Uri $cruUrl -OutFile "./qres.exe"
    $isQresDownload = $true
    Write-Host "qres.exe downloaded ok."
} catch {
        Write-Host "Something wrong. qres.exe is not downloaded"
}

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



try {
    # Iterate through subkeys in the DisplayDatabase registry path
    if ((Test-Path $fullPath) -And ($isCruDownload)) {
        takeRegOwnership -Path "$altPath"
        $subKeys = Get-ChildItem -Path $fullPath

        foreach ($subKey in $subKeys) {
            $curFullPath = "$subKey\00\00"
            $curAltPath = $curFullPath -replace "^HKEY_LOCAL_MACHINE\\", ""
            # Write-Host "Processing registry key: $curFullPath"

            # Check if Scaling value exists
            $scalingValue = Get-ItemProperty -Path "Registry::$curFullPath" -Name "Scaling"

            if ($null -ne $scalingValue) {
                if ($scalingValue.Scaling -ne 3) {
                    takeRegOwnership -Path $curAltPath
                    Set-ItemProperty -Path "Registry::$curFullPath" -Name "Scaling" -Value 3
                    #Write-Host "Scaling set to 3 (Full-screen Stretch)."
                } 
                # else {
                #    Write-Host "Already at Full-screen Stretch"
                # }
            }
        }
    }
    Start-Process "restart-only.exe" -WindowStyle Hidden
    Write-Host "Scaling configuration process completed."
} catch {
    Write-Host "Error: $_"
    Write-Host "Something's Wrong. Please go to NVIDIA Control Panel and set Full-screen manually"
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

# Get refresh-rate
function getRefreshRate(){
    # This doesn't work. Some monitors has float refresh rate. CurrentRefreshRate only returns
    return (Get-WmiObject -Namespace root\cimv2 -Class Win32_VideoController | 
    Select-Object -ExpandProperty CurrentRefreshRate -Unique | 
    Sort-Object)
}

$refreshRates = getRefreshRate

function changeRes(){

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
 
public static class Display {
    [StructLayout(LayoutKind.Sequential)]
    public struct DEVMODE {
        private const int CCHDEVICENAME = 0x20;
        private const int CCHFORMNAME = 0x20;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 0x20)]
        public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 0x20)]
        public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
        public int dmICMMethod;
        public int dmICMIntent;
        public int dmMediaType;
        public int dmDitherType;
        public int dmReserved1;
        public int dmReserved2;
        public int dmPanningWidth;
        public int dmPanningHeight;
    }
 
    [DllImport("user32.dll")]
    public static extern bool EnumDisplaySettings (string deviceName, int modeNum, ref DEVMODE devMode);  
 
    [DllImport("user32.dll")]
    public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);
}
'@
    
    $isDevMode = $false
    Add-Type -AssemblyName System.Windows.Forms
    $primaryScreen = [System.Windows.Forms.Screen]::PrimaryScreen
    
    $devMode = [Display+DEVMODE]::new()
    $devMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devMode)
     
    $devReturn = [Display]::EnumDisplaySettings($primaryScreen.DeviceName,-1,[ref]$devMode)
    if($devReturn) {
        if($devMode.dmDisplayFrequency -ne $refreshRates) {
            $devMode.dmDisplayFrequency = $refreshRates
            $devMode.dmPelsWidth = $newWidth
            $devMode.dmPelsHeight = $newHeight

            $devReturn = [Display]::ChangeDisplaySettings([ref]$devMode,0x00000001 -bor 0x00000008)
            if($devReturn -eq 0) {
                $devMode = [Display+DEVMODE]::new()
                $devMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devMode)
                $devReturn = [Display]::EnumDisplaySettings($primaryScreen.DeviceName,-1,[ref]$devMode)
                Write-Host "Display frequency has been changed, current display config: $($devMode.dmPelsWidth)x$($devMode.dmPelsHeight) $($devMode.dmDisplayFrequency)Hz"
                $isDevMode = $true
            }
            elseif($devReturn -eq 1) {
                Write-Host "A restart is required. Please manually change the resolution."
                $isDevMode = $false
            }
            else
            {
                Write-Host "Failed to change display frequency, please check if display is capable of running at $refreshRates`Hz"
                $isDevMode = $false
            }

        }
        else
        {
            Write-Host "Current display frequency is already at $newWidth x $newHeight $refreshRates`Hz"
            $isDevMode = $true
        }
    }
    elseif(!($isDevMode) -And $isQresDownload)
    {
        Write-Host "Something's wrong. Using qres.exe instead"
        Start-Process -FilePath ".\QRes.exe" -ArgumentList "/x:$newWidth /y:$newHeight /r:$refreshRates" -Wait
    }
    else {
        Write-Host "qres.exe is unavailable. Please change the resolution manually."
    }
}

Write-Host "Changing Screen Resolution to $newWidth $newHeight $refreshRates"
changeRes
