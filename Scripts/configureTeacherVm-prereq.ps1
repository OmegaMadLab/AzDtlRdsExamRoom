param(
  [Parameter(Mandatory=$true)]
  [string]
  $DomainName
)

Import-Module ServerManager

Write-Output "Enabling CredSSP..."
Enable-WSManCredSSP -Role Client -DelegateComputer "*.$DomainName" -Force
Enable-WSManCredSSP -Role Server -Force
Write-Output "CredSSP enabled."

# $allowed = @("WSMAN/*.$DomainName")

# $key = 'hklm:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
# if (!(Test-Path $key)) {
#     mkdir $key
# }
# New-ItemProperty -Path $key -Name AllowFreshCredentials -Value 1 -PropertyType Dword -Force            

# $key = Join-Path $key 'AllowFreshCredentials'
# if (!(Test-Path $key)) {
#     mkdir $key
# }
# $i = 1
# $allowed | ForEach-Object {
#     # Script does not take into account existing entries in this key
#     New-ItemProperty -Path $key -Name $i -Value $_ -PropertyType String -Force
#     $i++
# }

#Install RDS Features
Write-Output "Installing RDS components..."
Install-WindowsFeature -Name 'RDS-Connection-Broker', 'RDS-Licensing', 'RDS-Web-Access', 'RSAT-RDS-Tools' -IncludeAllSubFeature -IncludeManagementTools 

Write-Output "Enabling PSRemoting..."
Enable-PSRemoting -Force -verbose

Restart-Computer -Force -Confirm:$false

#Check for pending reboot, and eventually restart server
#Adapted from https://gist.github.com/altrive/5329377
#Based on <http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542>
# function Test-PendingReboot
# {
#  if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
#  if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
#  if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
#  try { 
#    $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
#    $status = $util.DetermineIfRebootPending()
#    if(($status -ne $null) -and $status.RebootPending){
#      return $true
#    }
#  }catch{}
 
#  return $false
# }

# if(Test-PendingReboot) {
#     Write-Verbose "There's a pending reboot. Restarting server..."
#     Restart-Computer -Force -Confirm:$false
# }



