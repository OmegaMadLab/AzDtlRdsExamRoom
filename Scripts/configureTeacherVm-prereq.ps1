param(
  [Parameter(Mandatory=$true)]
  [string]
  $DomainName
)

Import-Module ServerManager

$delegate = "*.$DomainName"
$wsman    = "WSMAN/*.$DomainName"

Write-Output "Starting enabling CredSSP" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append	
Enable-WSManCredSSP -Role Client -DelegateComputer $delegate -Force
Enable-WSManCredSSP -Role Server -Force
Write-Output "CredSSP enabled" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
	
Write-Output "Set TrustedHosts" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
Set-item wsman:localhost\client\trustedhosts -value $delegate -Force
Write-Output "TrustedHosts setup completed" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

Write-Output "Enable CredSSP Fresh NTLM Only" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name ConcatenateDefaults_AllowFreshNTLMOnly -Value 1 -PropertyType DWORD -Force | Out-Null
New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name AllowFreshCredentialsWhenNTLMOnly -Force | Out-Null
New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name 1 -Value $wsman -PropertyType String -Force | Out-Null
Write-Output "CredSSP Fresh NTLM Only enabled" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

#Install RDS Features
Write-Output "Installing RDS components..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
Install-WindowsFeature -Name 'RDS-Connection-Broker', 'RDS-Licensing', 'RDS-Web-Access', 'RSAT-RDS-Tools' -IncludeAllSubFeature -IncludeManagementTools 
Write-Output "RDS Components installed" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

Write-Output "Enabling PSRemoting..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
Enable-PSRemoting -Force -verbose
Write-Output "PSRemoting Enabled" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

Write-Output "Restarting..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
Restart-Computer -Force -Confirm:$false




