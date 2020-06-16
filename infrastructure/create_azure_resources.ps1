param(
    [Parameter(Mandatory=$true)]
    [String] $ResourceGroup,

    [Parameter(Mandatory=$true)]
    [String] $Region,

    [Parameter(Mandatory=$false)]
    [String] $Name
) 

function Write-Log {
  param( [string] $LogText)
  Write-Output -InputObject ("[{0}] - {1} . . ." -f $(Get-Date), $LogText )
}

Import-Module -Name bjd.Common.Functions

if([string]::IsNullOrEmpty($Name) ) {
  $appName = (New-Uuid).Substring(0,6)
}
else {
  $appName = $Name
}

Write-Log -LogText ("Creating Resource Group for {0}" -f $appName)
if((az group exists -g $ResourceGroup) -eq $false) {
  az group create -n $ResourceGroup -l $Region
}
$currentLocation    = $PWD.Path
$functionAppName    = "func{0}01" -f $appName
$funcStorageName    = "{0}sa001" -f $functionAppName
$eventHubNameSpace  = "hub{0}01" -f $appName
$jobName            = "stream{0}01" -f $appName
$eventHubName       = "sinewave"

Write-Log -LogText "Creating Event Hub Namespace"
az eventhubs namespace create -g $ResourceGroup -n $eventHubNameSpace -l $region --sku Standard --enable-auto-inflate --maximum-throughput-units 5 --enable-kafka

Write-Log -LogText "Creating Event Hub"
az eventhubs eventhub create -g $ResourceGroup --namespace-name $eventHubNameSpace -n $eventHubName --partition-count 1

Write-Log -LogText "Creating Azure Function Storage Account"
az storage account create --name $funcStorageName --location $Region --resource-group $ResourceGroup --sku Standard_LRS

Write-Log -LogText "Creating Azure Function"
az functionapp create --name $functionAppName --storage-account $funcStorageName --consumption-plan-location $Region  --os-type linux --resource-group $ResourceGroup  --functions-version 3  --runtime python  --runtime-version 3.8
az functionapp identity assign --name $functionAppName --resource-group $ResourceGroup

Write-Log -LogText "Setting up Azure Function Configuration"
$ehConnectionString=(az eventhubs namespace authorization-rule keys list -g $ResourceGroup --namespace-name $eventHubNameSpace --name RootManageSharedAccessKey -o tsv --query primaryConnectionString)
az functionapp config appsettings set -g $ResourceGroup -n $functionAppName --settings EVENT_HUB_NAMESPACE=$ehConnectionString
az functionapp config appsettings set -g $ResourceGroup -n $functionAppName --settings EVENT_HUB=$eventHubName

Write-Log -LogText "Deploying Function Code"
Set-Location -Path ..\src\sine-generator
func azure functionapp publish $functionAppName
Set-Location -Path $currentLocation

Write-Log -LogText "Deploying Stream Analytics"
Set-Location -Path ..\src\stream-analytic-jobs
$SubscriptionName=(az account show -o tsv --query name)
.\Create-Streamjob.ps1 -SubscriptionName $SubscriptionName -ResourceGroup $ResourceGroup -JobName $jobName -Region $Region -EventHubNamespace $eventHubNameSpace
Set-Location -Path $currentLocation

# echo Application name
Write-Log -LogText "------------------------------------"
Write-Log -LogText ("Infrastructure built successfully. Application Name: {0}" -f $appName)
Write-Log -LogText "------------------------------------"
