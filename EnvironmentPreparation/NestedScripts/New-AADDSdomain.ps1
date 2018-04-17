[CmdLetBinding()]

param (
    [string]$SubscriptionId,
    [string]$ManagedDomainName,
    [string]$ResourceGroupName,
    [string]$VnetName,
    [string]$SubnetName,
    [string]$Location,
    [string]$AdminUsername,
    [securestring]$AdminPassword
)

[System.ConsoleColor]$infoColor = 'Cyan'
[System.ConsoleColor]$warningColor = 'Yellow'
[System.ConsoleColor]$okColor = 'Green'
[System.ConsoleColor]$errorColor = 'Red'

$ErrorActionPreference = 'Stop'

$AaddsAdminUserUpn = "$AdminUsername@$managedDomainName"

# Retrieve the service principal for Azure AD Domain Services.
try {
  Write-Host "`nStarting AADDS deployment..." -ForegroundColor $infoColor
  Write-Host "`nRetrieving AAD service principal for AADDS..." -ForegroundColor $infoColor
  $appId = Get-AzureADServicePrincipal | Where-Object AppId -EQ "2565bd9d-da50-47d4-8b85-4c97f669dc36"
  if(!$appId) {
    Write-Host "AAD service principal for AADDS not found. Trying to create it..." -ForegroundColor $warningColor
    # Create the service principal for Azure AD Domain Services.
    New-AzureADServicePrincipal -AppId "2565bd9d-da50-47d4-8b85-4c97f669dc36"
    Write-Host "AAD service principal for AADDS successfully created." -ForegroundColor $okColor
  }
  else {
    Write-Host "AAD service principal for AADDS found." -ForegroundColor $okColor
  }
  
  # Retrieve the object ID of the 'AAD DC Administrators' group.
  Write-Host "`nRetrieving AAD DC Administrators group..." -ForegroundColor $infoColor
  $GroupObjectId = Get-AzureADGroup `
    -Filter "DisplayName eq 'AAD DC Administrators'" | `
    Select-Object ObjectId
  if(!$GroupObjectId) {
    Write-Host "AAD DC Administrators group not found. Trying to create it..." -ForegroundColor $warningColor
    # Create the delegated administration group for AAD Domain Services.
    $Group = New-AzureADGroup -DisplayName "AAD DC Administrators" `
      -Description "Delegated group to administer Azure AD Domain Services" `
      -SecurityEnabled $true -MailEnabled $false `
      -MailNickName "AADDCAdministrators"
    $GroupObjectId = $Group | Select-Object ObjectId
    Write-Host "AAD DC Administrators group successfully created." -ForegroundColor $okColor
  }
  else {
    Write-Host "AAD DC Administrators group found." -ForegroundColor $okColor
  }

  # Retrieve the object ID of the AADS admin user.
  Write-Host "`nRetrieving user $AaddsAdminUserUpn..." -ForegroundColor $infoColor
  $UserObjectId = Get-AzureADUser `
    -Filter "UserPrincipalName eq '$AaddsAdminUserUpn'" | `
    Select-Object ObjectId
  if(!$UserObjectId) {
    Write-Host "User $AaddsAdminUserUpn not found. Trying to create it..." -ForegroundColor $warningColor
    # Create the delegated administration group for AAD Domain Services.
    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $PasswordProfile.Password = "TempStrongPwd!!"
    $User = New-AzureADUser -AccountEnabled $true `
        -DisplayName "AADS Admin" `
        -UserPrincipalName $AaddsAdminUserUpn `
        -PasswordProfile $PasswordProfile `
        -MailNickName "AADDSAdmin" `
        -PasswordPolicies DisablePasswordExpiration
    $UserObjectId = $User | Select-Object ObjectId
    Set-AzureADUserPassword -ObjectId $UserObjectId.ObjectId -Password $AdminPassword -ForceChangePasswordNextLogin:$false
    
    Write-Host "User $AaddsAdminUserUpn successfully created." -ForegroundColor $okColor
  }
  else {
    Write-Host "User $AaddsAdminUserUpn found." -ForegroundColor $okColor
  }

  # Add the user to the 'AAD DC Administrators' group.
  Write-Host "`nAdding $AaddsAdminUserUpn to AAD DC Administrators group..." -ForegroundColor $infoColor
  Add-AzureADGroupMember -ObjectId $GroupObjectId.ObjectId -RefObjectId $UserObjectId.ObjectId
  Write-Host "Done." -ForegroundColor $okColor

  # Register the resource provider for Azure AD Domain Services with Resource Manager.
  Write-Host "`nRegistering resource provider for AADDS..." -ForegroundColor $infoColor
  Register-AzureRmResourceProvider -ProviderNamespace Microsoft.AAD
  Write-Host "Done." -ForegroundColor $okColor

  # Enable Azure AD Domain Services for the directory.
  $AaddsResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.AAD/DomainServices/$ManagedDomainName"
  $AaddsSubnetId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$VnetName/subnets/$SubnetName"
  Write-Host "`nEnabling AADDS..." -ForegroundColor $infoColor
  $ADDSdomain = New-AzureRmResource -ResourceId $AaddsResourceId `
    -Location $Location `
    -Properties @{"DomainName"=$ManagedDomainName; "SubnetId"=$AaddsSubnetId} `
    -ApiVersion 2017-06-01 -Force -Verbose
  $AADSDomain
  Write-Host "Done." -ForegroundColor $okColor  

  #Update Vnet DNS settings
  $Vnet = Get-AzureRmVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName
  $Vnet.DhcpOptions.DnsServers = $AADSDomain.Properties.domainControllerIpAddress
  $Vnet | Set-AzureRmVirtualNetwork

}
catch {
  Write-Host "Error while deploying AADDS:" -ForegroundColor $errorColor
  throw $_
}