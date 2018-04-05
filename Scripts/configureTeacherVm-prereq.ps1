Import-Module ServerManager

Enable-WSManCredSSP -Role Client -DelegateComputer $env:COMPUTERNAME -Force
Enable-WSManCredSSP -Role Server -Force

#the following is used because -delegatecomputer (above) doesn't appear to actually work properly.
Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp\PolicyDefaults\AllowFreshCredentialsDomain -Name WSMan -Value "WSMAN/$env:COMPUTERNAME"

Connect-WSMan -ComputerName $computer 
Set-Item "WSMAN:\$computer\service\auth\credssp" -Value $true 

#Install RDS Features
Write-Output "Installing RDS components..."
Install-WindowsFeature -Name 'RDS-Connection-Broker', 'RDS-Licensing', 'RDS-Web-Access', 'RSAT-RDS-Tools' -IncludeAllSubFeature -IncludeManagementTools 

Write-Output "Enabling PSRemoting..."
Enable-PSRemoting -Force -verbose

#Check for pending reboot, and eventually restart server
#Adapted from https://gist.github.com/altrive/5329377
#Based on <http://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542>
function Test-PendingReboot
{
 if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
 if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
 if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
 try { 
   $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
   $status = $util.DetermineIfRebootPending()
   if(($status -ne $null) -and $status.RebootPending){
     return $true
   }
 }catch{}
 
 return $false
}

if(Test-PendingReboot) {
    Write-Verbose "There's a pending reboot. Restarting server..."
    Restart-Computer -Force -Confirm:$false
}



