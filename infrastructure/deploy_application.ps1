param(
    [string] $AppName
)

$functionAppName = "func{0}01" -f $appName
$currentLocation = $PWD.Path

Set-Location -Path ..\src\sine-generator
func azure functionapp publish $functionAppName
Set-Location -Path $currentLocation