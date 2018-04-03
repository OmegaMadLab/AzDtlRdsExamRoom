# Find the virtual machine in Azure

$SubscriptionId = 'a52d6e89-dd24-483d-a769-13bddf3500c6'
$DevTestLabName = 'SJ-Obinu-lab'
$resourceGroupName = (Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}).ResourceGroupName
$virtualMachineName = 'SJ-TestVM'

$FullVMId = "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.DevTestLab/labs/$DevTestLabName/virtualmachines/$virtualMachineName"
 
$virtualMachine = Get-AzureRmResource -ResourceId $FullVMId -ODataQuery '$expand=Properties($expand=Artifacts)' -ExpandProperties

$props = $virtualMachine | Select Properties 

$subItems = Get-AzureRmResource | Where-Object {$_.ResourceGroupName -eq $props.Properties.computeId.Split('/')[4]} 

$virtualMachine.Properties

$NIC = $subItems | Where-Object ResourceType -eq Microsoft.Network/networkInterfaces | Get-AzureRmNetworkInterface

$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName 'SJ-Obinu-RDPTest2' -Name 'dtl-DC-NSG'

$NIC.NetworkSecurityGroup = $nsg
$NIC | Set-AzureRmNetworkInterface

$cse = $subItems | Where-Object ResourceType -eq Microsoft.Compute/virtualMachines/extensions 

$script = Get-AzureRmVMCustomScriptExtension -ResourceGroupName $cse.ResourceGroupName -Name ($cse.Name.Split('/')[1]) -vmName $virtualMachineName

$script.