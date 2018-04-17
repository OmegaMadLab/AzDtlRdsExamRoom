[CmdLetBinding()]

param (
    [string]$SubscriptionId,
    [pscredential]$AzureCredential,
    [string]$ManagedDomainName,
    [string]$AdminUsername,
    [securestring]$AdminPassword,
    [string]$ResourceGroupName,
    [string]$VnetName,
    [string]$VnetAddressSpace,
    [string]$Location
)

[System.ConsoleColor]$infoColor = 'Cyan'
[System.ConsoleColor]$warningColor = 'Yellow'
[System.ConsoleColor]$okColor = 'Green'
[System.ConsoleColor]$errorColor = 'Red'

$ErrorActionPreference = 'Stop'

Write-Host "`nLooking for NuGet package manager..." -ForegroundColor $infoColor
if((Get-PackageProvider -Name NuGet -ListAvailable).Version.toString().Replace(".","") -lt 285209) {
    Write-Host "NuGet version 2.8.5.201 or higher not found. Trying to install it..." -ForegroundColor $warningColor
    try {
        Install-PackageProvider -Name NuGet -Force -MinimumVersion 2.8.5.201
        Write-Host "NuGet package manager installed." -ForegroundColor $okColor
    }
    catch {
        Write-Host "Error while installing NuGet package manager:" -ForegroundColor $errorColor
        throw $_
    }
}
else {
    Write-Host "NuGet package manager found." -ForegroundColor $okColor
}

Write-Host "`nLooking for AzureAD PowerShell module..." -ForegroundColor $infoColor
if(!(Get-Module -Name AzureAD -ListAvailable)) {
    Write-Host "AzureAD PowerShell module not found. Trying to install it..." -ForegroundColor $warningColor
    try {
        Install-Module -Name AzureAD -Force -Confirm:$false
        Write-Host "AzureAD PowerShell module installed." -ForegroundColor $okColor
    }
    catch {
        Write-Host "Error while installing AzureAD PowerShell module:" -ForegroundColor $errorColor
        throw $_
    }
}
else {
    Write-Host "AzureAD PowerShell module found." -ForegroundColor $okColor
}

#Login to Azure Subscription
try {
    Write-Host "`nTrying to connect to subscription and Azure AD with specified credential..." -ForegroundColor $infoColor
    Login-AzureRmAccount -Subscription $SubscriptionId -Credential $AzureCredential

    #Retrieve AAD Tenant ID, and connect to it
    $TenantId = (Get-AzureRmSubscription -SubscriptionId $SubscriptionId).TenantId
    Connect-AzureAD -Credential $AzureCredential -TenantId $TenantId
    Write-Host "Connection successfull." -ForegroundColor $okColor
}
catch {
    Write-Host "Error while trying to connect:" -ForegroundColor $errorColor
    throw $_
}

# Get or create the resource group
try {
    $ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if(!$ResourceGroup)
    {
        Write-Host "Resource group '$ResourceGroupName' does not exist." -ForegroundColor $warningColor
        Write-Host "Creating resource group '$resourceGroupName' in location '$Location'..." -ForegroundColor $infoColor
        New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Host "Resource group successfully created." -ForegroundColor $okColor
    }
    else {
        Write-Host "Using existing resource group $ResourceGroupName." -ForegroundColor $infoColor
    }
}
catch {
    Write-Host "Error while trying to create resource group:" -ForegroundColor $errorColor
    throw $_
}


#Prepare Vnet for AADDS
# Create the dedicated subnet for AAD Domain Services.
$AaddsSubnetName = "AAD-Domain-Services"
$AaddsSubnetPrefix = "$($VnetAddressSpace.Substring(0,$VnetAddressSpace.IndexOf('/')))/24"

try {
    Write-Host "`nPreparing network infrastructure for AADDS..." -ForegroundColor $infoColor
    
    
    $AaddsSubnet = New-AzureRmVirtualNetworkSubnetConfig `
        -Name $AaddsSubnetName `
        -AddressPrefix $AaddsSubnetPrefix

    # Create the virtual network in which you will enable Azure AD Domain Services.
    $Vnet = New-AzureRmVirtualNetwork `
        -ResourceGroupName $ResourceGroupName `
        -Location $Location `
        -Name $VnetName `
        -AddressPrefix $VnetAddressSpace `
        -Subnet $AaddsSubnet

    Write-Host "`nNetwork infrastructure successfully created:" -ForegroundColor $okColor
    $vnetInfo = [ordered]@{
        "Vnet name:" = $VnetName;
        "Vnet address space:" = $VnetAddressSpace;
        "Subnet name:" = $AaddsSubnetName;
        "Subnet prefix:" = $AaddsSubnetPrefix;
    }
    $vnetInfo | Format-Table -HideTableHeaders | Out-String | ForEach-Object {Write-Host $_ -ForegroundColor $infoColor}
}
catch {
    Write-Host "Error while deploying network infrastructure:" -ForegroundColor $errorColor
    throw $_
}

#Deploy AADDS domain
.\NestedScripts\New-AADDSdomain.ps1 -SubscriptionId $SubscriptionId `
    -ManagedDomainName $ManagedDomainName `
    -ResourceGroupName $ResourceGroupName `
    -VnetName $VnetName `
    -SubnetName $AaddsSubnetName `
    -Location $Location `
    
#Configure Exam Rooms OUs and GPOs by deploying a management VM
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
    -Mode Incremental `
    -TemplateFile ".\NestedScripts\aaddsConsoleVm.json" `
    -VnetName $VnetName `
    -SubnetName $AaddsSubnetName `
    -VmName "aaddsConsole" `
    -AdminUsername

Get-ADUser -Credential $AzureCredential -