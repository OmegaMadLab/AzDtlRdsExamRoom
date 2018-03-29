<#
The MIT License (MIT)
 
Copyright (c) Microsoft Corporation
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
.SYNOPSIS
 
This script creates a new environment in the lab using an existing environment template.
 
.PARAMETER SubscriptionId
 
The subscription ID that the lab is created in.
 
.PARAMETER DevTestLabName
 
The name of the lab.
 
.PARAMETER VirtualMachineName
 
The virtual machine name to deploy to
 
.PARAMETER RepositoryName
 
The name of the repository in the lab.
 
.PARAMETER ArtifactName
 
The name of the artifact to be deployed
 
  
 
.PARAMETER Params
 
The parameters pairs to be passed into the artifact ie params_TestVMAdminUserName = adminuser params_TestVMAdminPassword = pwd
 
  
 
.NOTES
 
The script assumes that a lab exists, has a repository connected, and the artifact is in the repository.
#>
 
#Requires -Version 3.0
 
#Requires -Module AzureRM.Resources
 
param
 
(
 
[Parameter(Mandatory=$true, HelpMessage="The Subscription Id containing the DevTest lab")]
 
[string] $SubscriptionId,
 
[Parameter(Mandatory=$true, HelpMessage="The name of the DevTest Lab containing the Virtual Machine")]
 
[string] $DevTestLabName,
 
[Parameter(Mandatory=$true, HelpMessage="The name of the Virtual Machine")]
 
[string] $VirtualMachineName,
 
[Parameter(Mandatory=$true, HelpMessage="The repository where the artifact is stored")]
 
[string] $RepositoryName,
 
[Parameter(Mandatory=$true, HelpMessage="The artifact to apply to the virtual machine")]
 
[string] $ArtifactName,
 
[Parameter(ValueFromRemainingArguments=$true)]
 
$Params
)
# Set the appropriate subscription
 
Set-AzureRmContext -SubscriptionId $SubscriptionId | Out-Null
  
# Get the lab resource group name
 
$resourceGroupName = (Find-AzureRmResource -ResourceType 'Microsoft.DevTestLab/labs' | Where-Object { $_.Name -eq $DevTestLabName}).ResourceGroupName
 
if ($resourceGroupName -eq $null) { throw "Unable to find lab $DevTestLabName in subscription $SubscriptionId." }
 
# Get the internal repo name
 
$repository = Get-AzureRmResource -ResourceGroupName $resourceGroupName `
 
-ResourceType 'Microsoft.DevTestLab/labs/artifactsources' `
 
-ResourceName $DevTestLabName `
 
-ApiVersion 2016-05-15 `
 
| Where-Object { $RepositoryName -in ($_.Name, $_.Properties.displayName) } `
 
| Select-Object -First 1
 
if ($repository -eq $null) { "Unable to find repository $RepositoryName in lab $DevTestLabName." }
 
# Get the internal artifact name
 
$template = Get-AzureRmResource -ResourceGroupName $resourceGroupName `
 
-ResourceType "Microsoft.DevTestLab/labs/artifactSources/artifacts" `
 
-ResourceName "$DevTestLabName/$($repository.Name)" `
 
-ApiVersion 2016-05-15 `
 
| Where-Object { $ArtifactName -in ($_.Name, $_.Properties.title) } `
 
| Select-Object -First 1
 
if ($template -eq $null) { throw "Unable to find template $ArtifactName in lab $DevTestLabName." }
 
# Find the virtual machine in Azure
 
$FullVMId = "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName`
 
/providers/Microsoft.DevTestLab/labs/$DevTestLabName/virtualmachines/$virtualMachineName"
 
$virtualMachine = Get-AzureRmResource -ResourceId $FullVMId
 
# Generate the artifact id
 
$FullArtifactId = "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName`
 
/providers/Microsoft.DevTestLab/labs/$DevTestLabName/artifactSources/$($repository.Name)`
 
/artifacts/$($template.Name)"
 
# Handle the inputted parameters to pass through
 
$artifactParameters = @()
 
# Fill artifact parameter with the additional -param_ data and strip off the -param_
 
$Params | ForEach-Object {
 
if ($_ -match '^-param_(.*)') {
 
$name = $_.TrimStart('^-param_')
 
} elseif ( $name ) {
 
$artifactParameters += @{ "name" = "$name"; "value" = "$_" }
 
$name = $null #reset name variable
 
}
 
}
# Create structure for the artifact data to be passed to the action
 
$prop = @{
 
artifacts = @(
 
@{
 
artifactId = $FullArtifactId
 
parameters = $artifactParameters
 
}
 
)
 
}
# Check the VM
 
if ($virtualMachine -ne $null) {
 
# Apply the artifact by name to the virtual machine
 
$status = Invoke-AzureRmResourceAction -Parameters $prop -ResourceId $virtualMachine.ResourceId -Action "applyArtifacts" -ApiVersion 2016-05-15 -Force
 
if ($status.Status -eq 'Succeeded') {
 
Write-Output "##[section] Successfully applied artifact: $ArtifactName to $VirtualMachineName"
 
}
 
else {
 
Write-Error "##[error]Failed to apply artifact: $ArtifactName to $VirtualMachineName"
 
}
 
}
 
else {
 
Write-Error "##[error]$VirtualMachine was not found in the DevTest Lab, unable to apply the artifact"
 
}