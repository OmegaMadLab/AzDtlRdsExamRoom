param (
    [string] $StudentVmPrefix,
    [int] $StudentVmNumber    
)

Import-Module RemoteDesktop

###Configure RDS base deployment
#Compose Student VMs array
$RdsHosts = @()
for ($i = 0; $i -lt $StudentVmNumber; $i++) {
    $RdsHosts += "$StudentVmPrefix$StudentVmNumber"
}

#Define RDS Roles servername
$RdsBrokerSrv = "$env:COMPUTERNAME.$env:USERDNSDOMAIN"
$RdsLicenseSrv = "$env:COMPUTERNAME.$env:USERDNSDOMAIN"
$RdsWebAccessSrv ="$env:COMPUTERNAME.$env:USERDNSDOMAIN"

#Create a basic RDS deployment
$RdsParams = @{
    ConnectionBroker = $RdsBrokerSrv;
    WebAccessServer = $RdsWebAccessSrv;
    SessionHost = $RdsHosts;
}

New-SessionDeployment @RdsParams

#Configure Licensing
$RdsLicParams = @{
    LicenseServer = $RdsLicenseSrv;
    Mode = "PerUser";
    ConnectionBroker = $RdsBrokerSrv;
    Force = $true;
}
Set-RDLicenseConfiguration @RdsLicParams

###Configure Server Manager
.\SetServerManager.ps1 -DomainName $env:USERDNSDOMAIN -RdsVm $env:COMPUTERNAME -StudentVmPrefix $StudentVmPrefix -StudentVmNumber $StudentVmNumber