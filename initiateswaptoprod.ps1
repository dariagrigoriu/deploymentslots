param(
  [string]$ResourceGroup,
  [string]$SlotName
)

Switch-AzureMode -Name AzureResourceManager
CLS

# Apply target config to deployment slots
$ParametersObject = @{
	targetSlot  = "production"
}

Invoke-AzureResourceAction -ResourceGroupName $ResourceGroup -ResourceType Microsoft.Web/sites/slots -ResourceName $SlotName -Action applySlotConfig -Parameters $ParametersObject -ApiVersion 2015-07-01 -Force -Verbose
Write-Host "Production slot specific configuration elements applied"
 