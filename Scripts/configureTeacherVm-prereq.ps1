param(
  [Parameter(Mandatory=$true)]
  [string]
  $DomainName
)

Import-Module ServerManager


# Enabling CredSSP to execute part of configureTeacherVM-prereq.ps1 script with domain credentials,
# needed to configure RDS farm
$delegate = "*.$DomainName"

Write-Output "Starting enabling CredSSP" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append	
Enable-WSManCredSSP -Role Client -DelegateComputer $delegate -Force
Enable-WSManCredSSP -Role Server -Force
Write-Output "CredSSP enabled" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
	
Write-Output "Set TrustedHosts" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
Set-item wsman:localhost\client\trustedhosts -value $delegate -Force
Write-Output "TrustedHosts setup completed" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

Write-Output "Enable CredSSP Fresh Credentials" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
$allowed = @("WSMAN/*.$DomainName")

$key = 'hklm:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
if (!(Test-Path $key)) {
    mkdir $key
}
New-ItemProperty -Path $key -Name AllowFreshCredentials -Value 1 -PropertyType Dword -Force    
New-ItemProperty -Path $key -Name AllowFreshCredentialsWhenNTLMOnly -Value 1 -PropertyType Dword -Force    

$keyFresh = Join-Path $key 'AllowFreshCredentials'
if (!(Test-Path $keyFresh)) {
    mkdir $keyFresh
}
$i = 1
$allowed | ForEach-Object {
    # Script does not take into account existing entries in this key
    New-ItemProperty -Path $keyFresh -Name $i -Value $_ -PropertyType String -Force
    $i++
}

$keyFreshNTLM = Join-Path $key 'AllowFreshCredentialsWhenNTLMOnly'
if (!(Test-Path $keyFreshNTLM)) {
    mkdir $keyFreshNTLM
}
$i = 1
$allowed | ForEach-Object {
    # Script does not take into account existing entries in this key
    New-ItemProperty -Path $keyFreshNTLM -Name $i -Value $_ -PropertyType String -Force
    $i++
}
Write-Output "CredSSP Fresh NTLM Credentials" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

# Install RDS Features
Write-Output "Installing RDS components..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
Install-WindowsFeature -Name 'RDS-Connection-Broker', 'RDS-Licensing', 'RDS-Web-Access', 'RSAT-RDS-Tools' -IncludeAllSubFeature -IncludeManagementTools 
Write-Output "RDS Components installed" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

# Enable PS remoting and reboot
Write-Output "Enabling PSRemoting..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
Enable-PSRemoting -Force -verbose
Write-Output "PSRemoting Enabled" | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append

Write-Output "Restarting..." | Out-File -FilePath 'C:\WINDOWS\Temp\rds_deployment.log' -Append
Restart-Computer -Force -Confirm:$false




