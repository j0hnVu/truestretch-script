# Powershell script to modify config to do True Stretched.

## How the script works
1. When you logged in, the script will use Riot Client Local API to find the PUUID of the account.
2. Create the specific Valorant Config Folder for that account
3. Download the base GameUserSettings.ini and put in the specific folder
2. Replace the res with the true stretched res in the config file (If specified)
## Usage

``` 
irm https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/script.ps1 | iex
```

### If you want specific resolution:
```
irm https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/script.ps1 -OutFile script.ps1
powershell -ExecutionPolicy Bypass -File .\script.ps1 YourWidth YourHeight
```

### Example:
```
irm https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/script.ps1 -OutFile script.ps1
powershell -ExecutionPolicy Bypass -File .\script.ps1 1080 1080
```
