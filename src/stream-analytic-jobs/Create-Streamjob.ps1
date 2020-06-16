param(
    [Parameter(Mandatory=$true)]
    [string] $SubscriptionName, 

    [Parameter(Mandatory=$true)]
    [string] $ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string] $JobName,

    [Parameter(Mandatory=$true)]
    [string] $Region,

    [Parameter(Mandatory=$true)]
    [string] $EventHubNamespace    
)

function Update-Template {
    param(
        [string] $TemplatePath,
        [object[]] $Replacements
    )

    $data = Get-Content -Raw -Path $TemplatePath
    $output = New-TemporaryFile 

    foreach( $update in $Replacements) {
        $data = $data.Replace($update.Name, $update.Value)
    }

    $data | Out-File -FilePath $output -Encoding ascii
    return $output.FullName
}

Select-AzSubscription -SubscriptionName $SubscriptionName

#Template Configs
$jobConfigTemplate      = Join-Path -Path $PWD.Path -ChildPath "templates\job.template"
$inputConfigTemplate    = Join-Path -Path $PWD.Path -ChildPath "templates\input.template"
#$outputConfigTemplate   = Join-Path -Path $PWD.Path -ChildPath "templates\output.template"
$outputConfig           = Join-Path -Path $PWD.Path -ChildPath "templates\output.json"
$transformConfig        = Join-Path -Path $PWD.Path -ChildPath "templates\transforms.json"

#Create Job
$jobMappings = @(
    @{Name="{{LOCATION}}"; Value=$Region}
)
$jobConfig = Update-Template -TemplatePath $jobConfigTemplate -Replacements $jobMappings
New-AzStreamAnalyticsJob -ResourceGroupName $ResourceGroup -File $jobConfig -Name $JobName -Force

#Create Input
$eventHubPolicy = "RootManageSharedAccessKey"
$eventHubKey = Get-AzEventHubKey -ResourceGroupName $ResourceGroup -Namespace $EventHubNamespace -Name $eventHubPolicy | Select-Object -ExpandProperty PrimaryKey
$inputMappings = @(
    @{Name="{{EVENTHUB}}"; Value="sinewave"},
    @{Name="{{EVENTHUBNAMESPACE}}"; Value=$EventHubNamespace},
    @{Name="{{KEY}}"; Value=$eventHubKey}
)
$inputConfig = Update-Template -TemplatePath $inputConfigTemplate -Replacements $inputMappings
$jobInputName = "{0}-input" -f $JobName
New-AzStreamAnalyticsInput -ResourceGroupName $ResourceGroup -JobName $JobName -File $inputConfig -Name $jobInputName

#Create Output
#$outputMappings = @(
#    @{Name=""; Value=""},
#)
#$outputConfig = Update-Template -TemplatePath $outputConfigTemplate -Replacements $outputMappings
#$jobOutputName = "{0}-output" -f $JobName
#New-AzStreamAnalyticsOutput -ResourceGroupName $ResourceGroup -JobName $JobName -File $outputConfig -Name $jobOutputName

#Create Transform
$jobTransformaName = "{0}-transform" -f $JobName
New-AzStreamAnalyticsTransformation -ResourceGroupName $ResourceGroup -JobName $JobName -File $transformConfig -Name $jobTransformaName

#Clean Up
Remove-Item -Path $jobConfig  -Force
Remove-Item -Path $inputConfig -Force 