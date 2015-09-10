param(
  [string]$ResourceGroup,
  [string]$SlotName
)

Switch-AzureMode -Name AzureResourceManager
CLS

# Swap deployment slots
$ParametersObject = @{
	targetSlot  = "production"
}

Write-Host "Swap operation in progress"
Invoke-AzureResourceAction -ResourceGroupName $ResourceGroup -ResourceType Microsoft.Web/sites/slots -ResourceName $SlotName -Action slotsswap -Parameters $ParametersObject -ApiVersion 2015-07-01 -Force
Write-Host "Swap operation completed"
