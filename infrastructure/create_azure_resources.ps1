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

$functionAppName = "func{0}01" -f $appName
$funcStorageName = "{0}sa001" -f $functionAppName
$eventHubNameSpace = "hub{0}01" -f $appName
$eventHubName = "sinewave"

Write-Log -LogText "Creating Event Hub Namespace"
az eventhubs namespace create -g $ResourceGroup -n $eventHubNameSpace -l $region --sku Standard --enable-auto-inflate --maximum-throughput-units 5 --enable-kafka

Write-Log -LogText "Creating Event Hub"
az eventhubs eventhub create -g $ResourceGroup --namespace-name $eventHubNameSpace -n $eventHubName

Write-Log -LogText "Creating Azure Function Storage Account"
az storage account create --name $funcStorageName --location $Region --resource-group $ResourceGroup --sku Standard_LRS

Write-Log -LogText "Creating Azure Function"
az functionapp create --name $functionAppName --storage-account $funcStorageName --consumption-plan-location $Region  --os-type linux --resource-group $ResourceGroup  --functions-version 3  --runtime python  --runtime-version 3.8
az functionapp identity assign --name $functionAppName --resource-group $ResourceGroup

Write-Log -LogText "Creating Azure Function"
$ehConnectionString=(az eventhubs namespace authorization-rule keys list -g $ResourceGroup --namespace-name $eventHubNameSpace --name RootManageSharedAccessKey -o tsv --query primaryConnectionString)
az functionapp config appsettings set -g $ResourceGroup -n $functionAppName --settings EVENT_HUB_NAMESPACE=$ehConnectionString
az functionapp config appsettings set -g $ResourceGroup -n $functionAppName --settings EVENT_HUB=$eventHubName

# echo Application name
Write-Log -LogText "------------------------------------"
Write-Log -LogText ("Infrastructure built successfully. Application Name: {0}" -f $appName)
Write-Log -LogText "------------------------------------"
