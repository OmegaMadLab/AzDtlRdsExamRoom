param (
    [string] $DomainName,
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
$RdsBrokerSrv = "$env:COMPUTERNAME.$domainName"
$RdsLicenseSrv = "$env:COMPUTERNAME.$domainName"
$RdsWebAccessSrv ="$env:COMPUTERNAME.$domainName"

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

#Create collection
$RdsCollParams = @{
    CollectionName = "ExamRoom";
    CollectionDescription = "Exam Room"
    SessionHost = $RdsHosts;
    ConnectionBroker = $RdsBrokerSrv
}
New-RDSessionCollection @RdsCollParams

###Configure Server Manager
#.\SetServerManager.ps1 -DomainName $env:USERDNSDOMAIN -RdsVm $env:COMPUTERNAME -StudentVmPrefix $StudentVmPrefix -StudentVmNumber $StudentVmNumber