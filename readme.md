# Powershell script to modify config to do True Stretched.


## Usage

### If your res is 1280 - 960:
``` 
irm https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/1280-960.ps1 | iex
```

### If your res is 1080 - 1080:
``` 
irm https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/1080-1080.ps1 | iex
```



### If you want specific resolution:
```
irm https://raw.githubusercontent.com/j0hnVu/truestretch-script/refs/heads/main/1280-960.ps1 -OutFile 1280-960.ps1
powershell -ExecutionPolicy Bypass -File .\1280-960.ps1 $RES1 $RES2
```
