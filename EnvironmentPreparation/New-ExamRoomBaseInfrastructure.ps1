[CmdLetBinding()]

param (
    [string]$SubscriptionId,
    [pscredential]$AzureCredential,
    [string]$ManagedDomainName,
    [string]$AdminUsername,
    [securestring]$AdminPassword,
    [string]$AaddsResourceGroupName,
    [string]$AaadsVnetName,
    [string]$AaadsVnetAddressSpace,
    [string]$Location,
    [string]$ExamRoomEnvironmentPrefix,
    [int]$NumberOfExamRooms,
    [string]$SharedResourceGroupName,
    [string]$ExamRoomVnetName,
    [string]$ExamRoomVnetAddressSpace
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
        Write-Host "Error while installing NuGet package manager:`n" -ForegroundColor $errorColor
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
        Write-Host "Error while installing AzureAD PowerShell module:`n" -ForegroundColor $errorColor
        throw $_
    }
} 
else {
    Write-Host "AzureAD PowerShell module found." -ForegroundColor $okColor
}

#Login to Azure Subscription and AAD Tenant
try {
    Write-Host "`nTrying to connect to subscription and Azure AD with specified credential..." -ForegroundColor $infoColor
    Login-AzureRmAccount -Subscription $SubscriptionId -Credential $AzureCredential

    #Retrieve AAD Tenant ID, and connect to it
    $TenantId = (Get-AzureRmSubscription -SubscriptionId $SubscriptionId).TenantId
    Connect-AzureAD -Credential $AzureCredential -TenantId $TenantId
    Write-Host "Connection successfully established." -ForegroundColor $okColor
}
catch {
    Write-Host "Error while trying to connect:`n" -ForegroundColor $errorColor
    throw $_
}

#Enable Azure Firewall Preview - to be removed once service enters GA
Register-AzureRmProviderFeature -FeatureName AllowRegionalGatewayManagerForSecureGateway -ProviderNamespace Microsoft.Network
Register-AzureRmProviderFeature -FeatureName AllowAzureFirewall -ProviderNamespace Microsoft.Network

#Create an Azure AD Security Group for each exam room and teachers
try {
    Write-Host "`nTrying to create AAD security groups for each exam room..." -ForegroundColor $infoColor
    for ($i = 1; $i -le $NumberOfExamRooms; $i++)
    { 
        $ExamRoomId = ($i).ToString().PadLeft(2,'0')
        New-AzureADGroup -Description "ExamRoom$ExamRoomId-Students" `
            -DisplayName "ExamRoom$ExamRoomId-Students" `
            -MailEnabled $false `
            -SecurityEnabled $true `
            -MailNickName "ExamRoom$ExamRoomId-Students" | Out-Null
        Write-Host "Security group ExamRoom$ExamRoomId-Students successfully created." -ForegroundColor $okColor
    }
    $TeachersADGroup = New-AzureADGroup -Description "ExamRoom-Teachers" `
        -DisplayName "ExamRoom-Teachers" `
        -MailEnabled $false `
        -SecurityEnabled $true `
        -MailNickName "ExamRoom-Teachers" 
    Write-Host "Security group ExamRoom-Teachers successfully created." -ForegroundColor $okColor
}
catch {
    Write-Host "Error while trying to create AAD security groups:`n" -ForegroundColor $errorColor
    throw $_
}

#Get or create the resource groups
$ResourceGroupNames = @()
$ResourceGroupNames += $AaddsResourceGroupName
$ResourceGroupNames += $SharedResourceGroupName

try {
    $ResourceGroupNames | ForEach-Object {
        Write-Host "`nLooking for resource groups..." -ForegroundColor $infoColor
        $ResourceGroup = Get-AzureRmResourceGroup -Name $_ -ErrorAction SilentlyContinue
        if(!$ResourceGroup) {
            Write-Host "Resource group '$_' not found." -ForegroundColor $warningColor
            Write-Host "Creating resource group '$_' in location '$Location'..." -ForegroundColor $infoColor
            New-AzureRmResourceGroup -Name $_ -Location $Location
            Write-Host "Resource group successfully created." -ForegroundColor $okColor
        }
        else {
            Write-Host "Using existing resource group $_." -ForegroundColor $okColor
        }
    }
}
catch {
    Write-Host "Error while trying to create resource groups:`n" -ForegroundColor $errorColor
    throw $_
}

# Create automation account

$AutomationAcctnName = "ExamRoomAutomation"

New-AzureRmAutomationAccount -Name $AutomationAcctnName `
    -Location $Location `
    -ResourceGroupName $SharedResourceGroupName

# Create a RunAsAccount
.\NestedScripts\New-RunAsAccount.ps1 -ResourceGroup $SharedResourceGroupName `
    -AutomationAccountName $AutomationAcctnName `
    -SubscriptionId $SubscriptionId `
    -ApplicationDisplayName "ExamRoomAzureApp" `
    -SelfSignedCertPlainPassword "ExamR00MsTr0nG" `
    -SelfSignedCertNoOfMonthsUntilExpired 120

# Import Start/Stop AzureDtlVm runbook
Import-AzureRmAutomationRunbook -Path .\NestedScripts\ChangeDtlVmStatus.ps1 `
    -ResourceGroup $SharedResourceGroupName `
    -AutomationAccountName $AutomationAcctnName `
    -Type PowerShellWorkflow `
    -Published

#Create a new key vault to store AADDS domain admin credential
Register-AzureRmResourceProvider -ProviderNamespace Microsoft.KeyVault

$KeyVault = New-AzureRmKeyVault -VaultName "$ExamRoomEnvironmentPrefix-ExamRoom-KeyVault" `
                -ResourceGroupName $SharedResourceGroupName `
                -Location $Location `
                -EnabledForDeployment `
                -EnabledForTemplateDeployment `
                -EnabledForDiskEncryption `
                -Sku "Standard"

#Adding full permissions to current user
$CurrentUserUpn = (Get-AzureRmContext).Account.Id

$AdminCertPermissions = @("get","list","delete","create","import","update","managecontacts","getissuers","listissuers","setissuers","deleteissuers","manageissuers","recover","purge")
$AdminSecretPermissions = @("get","list","set","delete","backup","restore","recover","purge")
$AdminKeyPermissions = 	@("decrypt","encrypt","unwrapKey","wrapKey","verify","sign","get","list","update","create","import","delete","backup","restore","recover","purge")
$AdminStoragePermissions = @("get","list","delete","set","update","regeneratekey","getsas","listsas","deletesas","setsas")

#using emailaddres as workaround (https://github.com/Azure/azure-powershell/issues/5201)
Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVault.VaultName `
    -EmailAddress $CurrentUserUpn `
    -PermissionsToSecrets $AdminSecretPermissions `
    -PermissionsToKeys $AdminKeyPermissions `
    -PermissionsToCertificates $AdminCertPermissions `
    -PermissionsToStorage $AdminStoragePermissions

#Adding get and list permissions to teachers' group
$AutomationAcctnSecretPermissions = @("get","list")

Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVault.VaultName `
    -ServicePrincipalName "http://ExamRoomAzureApp" `
    -PermissionsToSecrets $TeachersSecretPermissions 

    
# # #Adding get and list permissions to teachers' group
# # $TeachersSecretPermissions = @("get","list")

# # Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVault.VaultName `
# #     -ObjectId $TeachersADGroup.ObjectId `
# #     -PermissionsToSecrets $TeachersSecretPermissions 



#Adding secret to store AADDS Admin password
$Secret = Set-AzureKeyVaultSecret -VaultName $KeyVault.VaultName -Name $AdminUsername -SecretValue $AdminPassword

#Prepare Vnet for AADDS
# Create the dedicated subnet for AAD Domain Services.
$AaddsSubnetName = "AAD-Domain-Services"
$AaddsSubnetPrefix = "$($AaadsVnetAddressSpace.Substring(0,$AaadsVnetAddressSpace.IndexOf('/')))/24"

try {
    Write-Host "`nPreparing network infrastructure for AADDS..." -ForegroundColor $infoColor
    
    
    $AaddsSubnet = New-AzureRmVirtualNetworkSubnetConfig `
        -Name $AaddsSubnetName `
        -AddressPrefix $AaddsSubnetPrefix

    # Create the virtual network in which you will enable Azure AD Domain Services.
    $VnetAadds = New-AzureRmVirtualNetwork `
        -ResourceGroupName $AaddsResourceGroupName `
        -Location $Location `
        -Name $AaadsVnetName `
        -AddressPrefix $AaadsVnetAddressSpace `
        -Subnet $AaddsSubnet

    Write-Host "`nNetwork infrastructure successfully created:" -ForegroundColor $okColor
    $vnetInfo = [ordered]@{
        "Vnet name:" = $AaadsVnetName;
        "Vnet address space:" = $AaadsVnetAddressSpace;
        "Subnet name:" = $AaddsSubnetName;
        "Subnet prefix:" = $AaddsSubnetPrefix;
    }
    $vnetInfo | Format-Table -HideTableHeaders | Out-String | ForEach-Object {Write-Host $_ -ForegroundColor $infoColor}
}
catch {
    Write-Host "Error while deploying network infrastructure:`n" -ForegroundColor $errorColor
    throw $_
}

#Deploy AADDS domain
$DnsIp = .\NestedScripts\New-AADDSdomain.ps1 -SubscriptionId $SubscriptionId `
    -ManagedDomainName $ManagedDomainName `
    -AdminUsername $AdminUsername `
    -AdminPassword $AdminPassword `
    -ResourceGroupName $AaddsResourceGroupName `
    -VnetName $AaadsVnetName `
    -SubnetName $AaddsSubnetName `
    -Location $Location `
    
#Configure Exam Rooms OUs and GPOs by deploying a management VM
New-AzureRmResourceGroupDeployment -ResourceGroupName $AaddsResourceGroupName `
    -Mode Incremental `
    -TemplateFile ".\NestedScripts\aaddsConsoleVm.json" `
    -VnetName $AaadsVnetName `
    -SubnetName $AaddsSubnetName `
    -VmName "aaddsConsole" `
    -DomainName $ManagedDomainName `
    -AdminUsername $AdminUsername `
    -AdminPassword $AdminPassword `
    -NumberOfExamRooms 5

#Prepare network infrastructure for exam rooms
$ExamRoomFirstSubnet = "$($ExamRoomVnetAddressSpace.Substring(0,$ExamRoomVnetAddressSpace.IndexOf('/')))"
$SubnetOctets = $ExamRoomFirstSubnet.Split('.')
$SubnetList = @()

for ($i = 0; $i -lt $NumberOfExamRooms; $i++)
{ 
    $ExamRoomId = ($i + 1).ToString().PadLeft(2,'0')
     
    try {
        Write-Host "`nPreparing network infrastructure for Exam Room $ExamRoomId..." -ForegroundColor $infoColor

        $ThirdOctet = ([int]$SubnetOctets[2] + ([math]::Round($i / 2, 0))).ToString()

        if($i % 2 -eq 0) {
            $LastOctet = "0/25"
        }
        else {
            $LastOctet = "128/25"
        }

        $StudentSubnetName = "ExamRoom$ExamRoomId-StudentSubnet"
        $SubnetPrefix = @($SubnetOctets[0], $SubnetOctets[1], $ThirdOctet, $LastOctet) -join '.'
        
        $SubnetList += New-AzureRmVirtualNetworkSubnetConfig `
            -Name $StudentSubnetName `
            -AddressPrefix $SubnetPrefix `
            -NetworkSecurityGroup $StudentNsg

        Write-Host "`nSubnet $StudentSubnetName ($SubnetPrefix) created." -ForegroundColor $okColor

        $ThirdOctet = ([int]$ThirdOctet += 8).ToString()
        $StudentSubnetName = "ExamRoom$ExamRoomId-StudentSubnet-InternetEnabled"
        $SubnetPrefix = @($SubnetOctets[0], $SubnetOctets[1], $ThirdOctet, $LastOctet) -join '.'

        $SubnetList += New-AzureRmVirtualNetworkSubnetConfig `
            -Name $StudentSubnetName `
            -AddressPrefix $SubnetPrefix `
            -NetworkSecurityGroup $StudentNsg

        Write-Host "`nSubnet $StudentSubnetName ($SubnetPrefix) created." -ForegroundColor $okColor

        $ThirdOctet = ([int]$ThirdOctet += 8).ToString()
        $TeacherSubnetName = "ExamRoom$ExamRoomId-TeacherSubnet"
        $SubnetPrefix = @($SubnetOctets[0], $SubnetOctets[1], $ThirdOctet, $LastOctet) -join '.'

        $SubnetList += New-AzureRmVirtualNetworkSubnetConfig `
            -Name $TeacherSubnetName `
            -AddressPrefix $SubnetPrefix 

        Write-Host "`nSubnet $TeacherSubnetName ($SubnetPrefix) created." -ForegroundColor $okColor
    }
    catch {
        Write-Host "Error while deploying network infrastructure:`n" -ForegroundColor $errorColor
        throw $_
    }
}

try {
    $VnetExamRoom = New-AzureRmVirtualNetwork `
                -ResourceGroupName $SharedResourceGroupName `
                -Location $Location `
                -Name "$ExamRoomEnvironmentPrefix-ExamRoomVnet" `
                -AddressPrefix $ExamRoomVnetAddressSpace `
                -Subnet $SubnetList `
                -DnsServer $DnsIp

    Write-Host "`nVirtual network "$ExamRoomEnvironmentPrefix-ExamRoomVnet" successfully created" -ForegroundColor $okColor

    #Create peering between AADDS vnet and ExamRoom vnet
    Add-AzureRmVirtualNetworkPeering -Name "AADDS-to-ExamRoom" `
        -VirtualNetwork $VnetAadds `
        -RemoteVirtualNetworkId $VnetExamRoom.Id

    Add-AzureRmVirtualNetworkPeering -Name "ExamRoom-to-AADDS" `
        -VirtualNetwork $VnetExamRoom `
        -RemoteVirtualNetworkId $VnetAadds.Id
    Write-Host "`nVirtual network peering between Exam Room vnet and AADDS vnet successfully created" -ForegroundColor $okColor
    
}
catch {
    Write-Host "Error while deploying network infrastructure:`n" -ForegroundColor $errorColor
    throw $_
}

$ExamRoomStudentNoInternetAddressRange = "$(($VnetExamRoom.Subnets | Where-Object Name -eq "ExamRoom01-StudentSubnet").AddressPrefix.Split("/")[0])/21"
#$ExamRoomStudentInternetAddressRange = "$(($VnetExamRoom.Subnets | Where-Object Name -eq "ExamRoom01-StudentSubnet-InternetEnabled").AddressPrefix.Split("/")[0])/21"
$ExamRoomStudentAddressRange = "$(($VnetExamRoom.Subnets | Where-Object Name -eq "ExamRoom01-StudentSubnet").AddressPrefix.Split("/")[0])/20"
#$ExamRoomTeacherAddressRange = ($VnetExamRoom.Subnets | Where-Object Name -eq "ExamRoom01-TeacherSubnet").AddressPrefix.Split("/")[0]

try {
    Write-Host "`nPreparing network security group for Exam Rooms..." -ForegroundColor $infoColor
    #Create an NSG rule to allow RDP traffic in from the Internet to the subnets.
    $rule1 = New-AzureRmNetworkSecurityRuleConfig -Name 'Allow-RDP-All' -Description 'Allow RDP' `
        -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 `
        -SourceAddressPrefix Internet -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 3389

    #Create an NSG rule to block all outbound traffic between students' subnet.
    $rule2 = New-AzureRmNetworkSecurityRuleConfig -Name 'Deny-Students-All' -Description "Deny all communication between students" `
        -Access Deny -Protocol Tcp -Direction Outbound -Priority 200 `
        -SourceAddressPrefix $ExamRoomStudentAddressRange -SourcePortRange * `
        -DestinationAddressPrefix $ExamRoomStudentAddressRange -DestinationPortRange *

    #Create an NSG rule to block all outbound traffic from the ExamRoomStudentNoInternetAddressRange to the Internet (inbound blocked by default).
    $rule3 = New-AzureRmNetworkSecurityRuleConfig -Name 'Deny-Internet-All' -Description "Deny all Internet" `
        -Access Deny -Protocol Tcp -Direction Outbound -Priority 1000 `
        -SourceAddressPrefix $ExamRoomStudentNoInternetAddressRange -SourcePortRange * `
        -DestinationAddressPrefix Internet -DestinationPortRange *

    #Create a network security group (NSG)
    $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $SharedResourceGroupName `
        -Location $location `
        -Name "$ExamRoomEnvironmentPrefix-ExamRoom-NSG" `
        -SecurityRules $rule1,$rule2,$rule3

    Write-Host "`nNetwork security group `"$ExamRoomEnvironmentPrefix-ExamRoom-NSG`" successfully created" -ForegroundColor $okColor

    #Associate the NSG to the students' subnet.
    $VnetExamRoom.Subnets | Where-Object Name -like '*Students*' | ForEach-Object {
        $_.NetworkSecurityGroup = $nsg
        # Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $VnetExamRoom `
        #     -Name $_.Name `
        #     -AddressPrefix $_.AddressPrefix `
        #     -NetworkSecurityGroup $nsg
    }

    $VnetExamRoom | Set-AzureRmVirtualNetwork
    Write-Host "`nNetwork security group `"$ExamRoomEnvironmentPrefix-ExamRoom-NSG`" linked to appropriate subnets" -ForegroundColor $okColor
}
catch {
    Write-Host "Error while deploying network security group:`n" -ForegroundColor $errorColor
    throw $_
}