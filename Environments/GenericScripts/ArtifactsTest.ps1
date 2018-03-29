# Find the virtual machine in Azure

$SubscriptionId = 'a52d6e89-dd24-483d-a769-13bddf3500c6'
$DevTestLabName = 'SJ-Obinu-lab'
$resourceGroupName = (Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}).ResourceGroupName
$virtualMachineName = 'SJ-TestVM'

$FullVMId = "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DevTestLab/labs/$DevTestLabName/virtualmachines/$virtualMachineName"
 
$virtualMachine = Get-AzureRmResource -ResourceId $FullVMId -ODataQuery '$expand=Properties($expand=Artifacts)' -ExpandProperties


$virtualMachine.Properties