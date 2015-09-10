param(
  [string]$AzureLocation1,
  [string]$AzureLocation2
)

#$AzureLocation1 = "West US"
#$AzureLocation2 = "West Europe"

# Use location as naming suffix to identify resources
$LocationString1 = $AzureLocation1 -Replace '\s','' 
$LocationString2 = $AzureLocation2 -Replace '\s',''

$ResourceGroupName = "AzureConDemoRG"
$AppServicePlanName = "ACDemoPlan"
$AppName = "ACDemoApp"
$SlotName = "Stage"

# Helper function for new App Service Plan
Function New-DemoAppServicePlan($ResourceGroupName, $AzureLocation, $PlanName, $SkuName = "S1", $SkuTier = "Standard") 
{ 
    $FullObject = @{ 
    location = $AzureLocation 
        sku = @{ 
        name = $SkuName 
        tier = $SkuTier 
        } 
    }
    
    New-AzureResource -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Web/serverfarms -Name $PlanName -IsFullObject -PropertyObject $FullObject -OutputObjectFormat New -ApiVersion 2015-08-01 -Force 
} 

#Create ARM resources
Switch-AzureMode -Name AzureResourceManager 
CLS

Write-Host "Creating the AzureCon demo environment"

Write-Host "Creating Resource Groups"
New-AzureResourceGroup -Name ($ResourceGroupName + $LocationString1) -Location $AzureLocation1 -Force 
New-AzureResourceGroup -Name ($ResourceGroupName + $LocationString2) -Location $AzureLocation2 -Force 

Write-Host "Creating App Service Plans" 
New-DemoAppServicePlan ($ResourceGroupName + $LocationString1) $AzureLocation1 ($AppServicePlanName + $LocationString1)
New-DemoAppServicePlan ($ResourceGroupName + $LocationString2) $AzureLocation2 ($AppServicePlanName + $LocationString2)

Write-Host "Creating demo web apps and deployment slots" 
New-AzureWebApp -ResourceGroupName ($ResourceGroupName + $LocationString1) -Name ($AppName + $LocationString1) -Location $AzureLocation1 -AppServicePlan ($AppServicePlanName + $LocationString1)
New-AzureWebApp -ResourceGroupName ($ResourceGroupName + $LocationString1) -Name ($AppName + $LocationString1) -SlotName $SlotName -Location $AzureLocation1 -AppServicePlan ($AppServicePlanName + $LocationString1)

New-AzureWebApp -ResourceGroupName ($ResourceGroupName + $LocationString2) -Name ($AppName + $LocationString2) -Location $AzureLocation2 -AppServicePlan ($AppServicePlanName + $LocationString2)
New-AzureWebApp -ResourceGroupName ($ResourceGroupName + $LocationString2) -Name ($AppName + $LocationString2) -SlotName $SlotName -Location $AzureLocation2 -AppServicePlan ($AppServicePlanName + $LocationString2)

# Create PROD slot app settings
Write-Host "Creating app settings" 

$ProdAppSettingsObject = @{ 
    AZURECON_STICKY = "PROD"; 
    AZURECON_NON_STICKY = "PROD" 
} 
New-AzureResource -ResourceGroupName ($ResourceGroupName + $LocationString1) -ResourceType Microsoft.Web/sites/Config -Name (($AppName + $LocationString1) + "/appsettings") -PropertyObject $ProdAppSettingsObject -OutputObjectFormat New -ApiVersion 2015-08-01 -Force 

# Create slot app settings
$StageAppSettingsObject = @{ 
    AZURECON_STICKY = "STAGE"; 
    AZURECON_NON_STICKY = "STAGE" 
} 
New-AzureResource -ResourceGroupName ($ResourceGroupName + $LocationString1) -ResourceType Microsoft.Web/sites/slots/Config -Name (($AppName + $LocationString1) + "/" + $SlotName + "/appsettings") -PropertyObject $StageAppSettingsObject -OutputObjectFormat New -ApiVersion 2015-08-01 -Force 

# Mark config elements as sticky
 
$StickyConfigObject = @{
	appSettingNames = @("AZURECON_STICKY")    
}

New-AzureResource -ResourceGroupName ($ResourceGroupName + $LocationString1) -ResourceType Microsoft.Web/sites/Config -ResourceName (($AppName + $LocationString1) + "/slotConfigNames") -Properties $StickyConfigObject -ApiVersion 2015-08-01 -Force

# Configure Traffic Manager
$TMDomain = "AzureConDemoTM" 
try 
{ 
    $WATM_Profile = New-AzureTrafficManagerProfile -Name $TMDomain -ResourceGroupName ($ResourceGroupName + $LocationString1) -ProfileStatus Enabled -TrafficRoutingMethod Performance -RelativeDnsName $TMDomain -TTL 300 -MonitorProtocol HTTP -MonitorPort 80 -MonitorPath "/"
    $WATM_Profile = Add-AzureTrafficManagerEndpointConfig -EndpointName ($AppName + $LocationString1) -EndpointStatus Enabled -Target (($AppName + $LocationString1) + ".azurewebsites.net") -TrafficManagerProfile $WATM_Profile -Type ExternalEndpoints -EndpointLocation $AzureLocation1 -Priority 1 
    $WATM_Profile = Add-AzureTrafficManagerEndpointConfig -EndpointName ($AppName + $LocationString2) -EndpointStatus Enabled -Target (($AppName + $LocationString2) + ".azurewebsites.net") -TrafficManagerProfile $WATM_Profile -Type ExternalEndpoints -EndpointLocation $AzureLocation2 -Priority 2   
    
    Set-AzureTrafficManagerProfile -TrafficManagerProfile $WATM_Profile 
    Enable-AzureTrafficManagerProfile -Name $TMDomain -ResourceGroupName ($ResourceGroupName + $LocationString1)
    Get-AzureTrafficManagerProfile -Name $TMDomain -ResourceGroupName ($ResourceGroupName + $LocationString1)
} 
catch  
{ 
       Write-Host "Bypassing Traffic Manager configuration"    
} 
